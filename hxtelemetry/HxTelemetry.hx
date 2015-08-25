package hxtelemetry;

import sys.net.Socket;
import amf.io.Amf3Writer;
import haxe.ds.StringMap;
import haxe.io.Bytes;

#if cpp
  import cpp.vm.Thread;
  import cpp.vm.Mutex;
  using hxtelemetry.CppHxTelemetry;
#elseif neko
  import neko.vm.Thread;
  import neko.vm.Mutex;
  using hxtelemetry.NekoHxTelemetry;
#end

class Config
{
  public function new() {};
  public var app_name:String = "My App";
  public var host:String = "localhost";
  public var port:Int = 7934;
  public var cpu_usage:Bool = true;
  public var profiler:Bool = true;
  public var trace:Bool = true;
  public var allocations:Bool = true;
  public var activity_descriptors:Array<ActivityDescriptor> = null;
}

typedef ActivityDescriptor = {
  name:String,
  description:String,
  color:Int
};

class Timing {
  // Garbage collection is the only cross-platform / cross-framework activity
  // Frameworks can insert more descriptors
  public static inline var GC:String = ".gc";
  public static var DEFAULT_DESCRIPTORS:Array<ActivityDescriptor> = [
    { name:GC, description:"Garbage Collection", color:0xdd5522 }
  ];

  public static inline var FRAME_DELIMITER:String = ".enter";
}

// In debug mode, tell us where the existing thread was instantiated from
#if debug
    typedef ThreadExist = Array<haxe.CallStack.StackItem>;
#else
    typedef ThreadExist = Bool;
#end

#if cpp
  @:allow(hxtelemetry.CppHxTelemetry)
#elseif neko
  @:allow(hxtelemetry.NekoHxTelemetry)
#end
class HxTelemetry
{
  // Member objects
  var _config:Config;
  var _writer:Thread;

  var _thread_num:Int;

  private static var _threads:haxe.ds.IntMap<ThreadExist> = new haxe.ds.IntMap<ThreadExist>();
  private static var _mutex:Mutex = new Mutex();

  // Timing helpers
  static var _abs_t0_usec:Float = Date.now().getTime()*1000;
  static inline function timestamp_ms():Float { return _abs_t0_usec/1000 + haxe.Timer.stamp()*1000; };
  static inline function timestamp_us():Float { return _abs_t0_usec + haxe.Timer.stamp()*1000000; };

  public function new(config:Config=null)
  {
    if (config==null) config = new Config();
    _config = config;

    if (_config.activity_descriptors==null) {
      _config.activity_descriptors = [];
    }
    _config.activity_descriptors = Timing.DEFAULT_DESCRIPTORS.concat(_config.activity_descriptors);

    //trace("Starting writer thread...");
    _writer = Thread.create(start_writer);
    _writer.sendMessage(Thread.current());
    _writer.sendMessage(config.host);
    _writer.sendMessage(config.port);
    _writer.sendMessage(config.app_name);
    _writer.sendMessage(haxe.Serializer.run(config.activity_descriptors));

    if (!Thread.readMessage(true)) {
      _writer = null;
      return;
    }

    // Trace override for capture:
    // TODO: doesn't support multiple instances?
    if (config.trace) {
      var oldTrace = haxe.Log.trace; // store old function
      haxe.Log.trace = function( v:Dynamic, ?infos ) : Void {
        var s:String = Std.string(v);

        // handle "rest parameters" / multi trace args
        if (infos!=null && infos.customParams!=null) {
          for( v in infos.customParams )
            s += "," + v;
        }

        if (_writer!=null) _writer.sendMessage({"name":".trace", "value":(infos==null ? '' : infos.fileName + ":" + infos.lineNumber + ": ")+s});
        oldTrace(v,infos);
      }
    }

    validate_config();

    _thread_num = init_profiler_for_this_thread();
  }

  // start profiler, mutex guarantees a single profiler per thread
  private function init_profiler_for_this_thread():Int
  {
    var thread_num:Int = -1;

    if (_config.profiler) {
      _mutex.acquire();
      thread_num = start_profiler();
      if (_threads.exists(thread_num)) {
        _mutex.release();
#if debug
        trace("Already instantiated HXTelemetry from this thread, at:"+haxe.CallStack.toString(_threads.get(thread_num))+"\n");
#end
        throw "Cannot instance more than one HXTelemetry per Thread, triggered at:";
      }
#if debug
      var exist = haxe.CallStack.callStack();
#else
      var exist = true;
#end
      _threads.set(thread_num, exist);
      _mutex.release();
    }

    return thread_num;
  }

  // Protocol only sends memory values if they've changed
  var _last_gctotal:Int = -1;
  var _last_gcused:Int = -1;

  public function advance_frame(e=null)
  {
    if (_writer==null) return;

    do_advance_frame();

    // Special-case frame delimiter
    send_frame_delimiter();
  }

  var _last = timestamp_us();
  var _activity_stack_name:Array<String> = [];
  var _activity_stack_time:Array<Float> = [];
  var _hier_name:String = "";

  public inline function telemetry_error(err:String):Void
  {
    trace("Telemetry terminating at:");
    trace(haxe.CallStack.toString(haxe.CallStack.callStack()));
    _writer.sendMessage({"exit":true});
    _writer = null;
  }

  public function start_timing(name:String):Void
  {
    if (_writer==null) return;

    var t = timestamp_us();
    _activity_stack_name.push(name);
    _activity_stack_time.push(t);
    _hier_name += name;
  }

  public function end_timing(name:String):Void
  {
    if (_writer==null) return;

    disable_alloc_tracking(true);
    var t:Float = timestamp_us();
    var data:Dynamic = {"name":_hier_name,"delta":Std.int(t-_last)}
    var top = _activity_stack_name.pop();
    var t0 = _activity_stack_time.pop();
		if (top==name) {
			data.span = Std.int(t-t0);
			_writer.sendMessage(data);
      _hier_name = _hier_name.substr(0, _hier_name.length-name.length);
		} else {
			telemetry_error("WARNING: Inconsistent start/end timing, stack expected "+name+" but got "+top);
		}

    _last = t;
    disable_alloc_tracking(false);
  }

  private var _restart:Array<String> = [];
  public function send_frame_delimiter():Void
  {
    if (_writer==null) return;

    disable_alloc_tracking(true);
    var t:Float;

    // Stop/restart items still in stack
		while (_activity_stack_name.length>0) {
			var cur = _activity_stack_name[_activity_stack_name.length-1];
			_restart.push(cur);
			end_timing(cur);
		}

		// Send delimiter
		t = timestamp_us();
		var data:Dynamic = {"name":Timing.FRAME_DELIMITER,"delta":Std.int(t-_last)}
		_writer.sendMessage(data);
    _last = t;

    // Restart stopped activities
		while (_restart.length>0) { start_timing(_restart.pop()); }
    disable_alloc_tracking(false);
  }

  public function unwind_stack():String
  {
    var stack:String = _hier_name;
    _hier_name = "";
    return stack;
  }

  public function rewind_stack(stack:String):Void
  {
    if (_hier_name.length>0) {
      telemetry_error("Cannot rewind stack when not empty!");
    }
    _hier_name = stack;
  }

  private static function start_writer():Void
  {
    var socket:Socket = null;
    var writer:Amf3Writer;

    var main_thread:Thread = Thread.readMessage(true);
    var host:String = Thread.readMessage(true);
    var port:Int = Thread.readMessage(true);
    var app_name:String = Thread.readMessage(true);
    var activity_descriptors:String = Thread.readMessage(true);

    function cleanup()
    {
      if (socket!=null) {
        socket.close();
        socket = null;
      }
      writer = null;
    }

    var switch_to_nonamf = true;
    var amf_mode = true;

    function write_object(data:Dynamic) {
      try {
        if (!amf_mode) {
          var msg:String = haxe.Serializer.run(data);
          socket.output.writeByte(1);
          socket.output.writeInt32(msg.length);
          socket.output.writeString(msg);
        } else {
          writer.write(data);
        }
      } catch (e:Dynamic) {
        cleanup();
      }
    }

    // Creating sockets seems to need mutex
    _mutex.acquire();

    var connected = false;
    var retries = 3;
    function try_connect() {
      socket = new Socket();
      try {
        socket.connect(new sys.net.Host(host), port);
        if (amf_mode) {
          writer = new Amf3Writer(socket.output);
        }
        write_object({"name":".swf.name","value":app_name, "hxt":switch_to_nonamf,"activity_descriptors":activity_descriptors});
        if (switch_to_nonamf) {
          amf_mode = false;
          writer = null;
        } else {
          _mutex.release();
          throw "HXTelemetry no longer supports amf mode!";
        }
        connected = true;
      } catch (e:Dynamic) { }
    }

    while (true) {
      try_connect();
      if (connected) {
        main_thread.sendMessage(true);
        break;
      } else if (--retries == 0) {
        //trace("HxTelemetry failed to connect to "+host+":"+port);
        main_thread.sendMessage(false);
        break;
      } else {
        Sys.sleep(0.1);
      }
    }

    _mutex.release();

    while (socket!=null) {
      // TODO: Accept timing data, too
      var data:Dynamic = Thread.readMessage(true);

      if (data.dump) {
        disable_alloc_tracking(true);
        try {
          dump_telemetry_frame(data.thread_num, socket.output, write_object);
        } catch (e:Dynamic) {
          // Host most likely disconnected
          if (Std.string(e).toLowerCase().indexOf("eof")>=0) {
            cleanup();
          } else {
            trace("Rethrowing: "+e);
            throw e;
          }
        }
        disable_alloc_tracking(false);
      } else {
        write_object(data);
        if (data.exit) {
          cleanup();
        }
      }
    }

    // Disable allocations and drain the stats to prevent a memory leak
    // (actually destroying the Telemetry instance is tricky, as GC
    // finalizers can call into it during the destruction...)
    disable_alloc_tracking(true);
    while (true) {
      var data:Dynamic = Thread.readMessage(true);
      if (data.dump) {
        dump_telemetry_frame(data.thread_num, null, null);
      }
    }
  }

  public inline static function disable_alloc_tracking(set_disabled:Bool):Void
  {
#if cpp
    CppHxTelemetry.disable_alloc_tracking(set_disabled);
#end
  }

  public inline static function dump_telemetry_frame(thread_num:Int,
                                                     output:haxe.io.Output,
                                                     write_object:Dynamic->Void):Void
  {
#if cpp
    CppHxTelemetry.dump_telemetry_frame(thread_num, output, write_object);
#end
  }

}
