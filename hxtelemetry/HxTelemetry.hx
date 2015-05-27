package hxtelemetry;

import sys.net.Socket;
import amf.io.Amf3Writer;
import haxe.ds.StringMap;

#if cpp
  import cpp.vm.Thread;
  import cpp.vm.Mutex;
#end
//import haxe.CallStack;

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

typedef ActivityStackElem = {
  name:String,
  t0:Float
}

typedef ActivityDescriptor = {
  name:String,
  description:String,
  color:Int
};

class Timing {
  // Couldn't get an enum to work well wrt scope/access, still needed toString() anyway

  // Scout compatibility issue - real names
  public static inline var GC:String = ".gc";

  public static var DEFAULT_DESCRIPTORS:Array<ActivityDescriptor> = [
    { name:".gc", description:"Garbage Collection", color:0xdd5522 }
  ];

  public static inline var FRAME_DELIMITER:String = ".enter";
}

#if debug
    typedef ThreadExist = Array<haxe.CallStack.StackItem>;
#else
    typedef ThreadExist = Bool;
#end

class HxTelemetry
{
  // Member objects
  var _config:Config;
  var _writer:Thread;

  var _thread_num:Int;
  private static var _hxt_threads:haxe.ds.IntMap<ThreadExist> = new haxe.ds.IntMap<ThreadExist>();
  private static var mutex:Mutex = new Mutex();

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
      haxe.Log.trace = function( v, ?infos ) : Void {
        if (_writer!=null) _writer.sendMessage({"name":".trace", "value":(infos==null ? '' : infos.fileName + ":" + infos.lineNumber + ": ")+cast(v, String)});
        oldTrace(v,infos);
      }
    }

#if cpp
    if (_config.allocations && !_config.profiler) {
      throw "HxTelemetry config.allocations requires config.profiler";
    }

    if (_config.profiler) {
#if !HXCPP_STACK_TRACE
      throw "Using the HXTelemetry Profiler requires -D HXCPP_STACK_TRACE or in project.xml: <haxedef name=\"HXCPP_STACK_TRACE\" />";
#end
      mutex.acquire();
      _thread_num = untyped __global__.__hxcpp_hxt_start_telemetry(_config.profiler, _config.allocations);
      if (_hxt_threads.exists(_thread_num)) {
        mutex.release();
#if debug
        trace("Already instantiated HXTelemetry from this thread, at:"+haxe.CallStack.toString(_hxt_threads.get(_thread_num))+"\n");
#end
        throw "Cannot instance more than one HXTelemetry per Thread, triggered at:";
      }
#if debug
      var exist = haxe.CallStack.callStack();
#else
      var exist = true;
#end
      _hxt_threads.set(_thread_num, exist);
      mutex.release();
    }

#end
  }

//  function setup_event_loop():Void
//  {
//#if openfl_legacy
//    openfl.Lib.stage.addEventListener("HXT_BEFORE_FRAME", advance_frame);
//#elseif openfl
//    openfl.Lib.current.stage.addEventListener("HXT_BEFORE_FRAME", advance_frame);
//#elseif lime
//    trace("Does lime have an event loop?");
//#else
//    trace("TODO: create separate thread for event loop? e.g. commandline tools");
//#end
//  }

  public function advance_frame(e=null)
  {
    if (_writer==null) return;

#if cpp
    untyped __global__.__hxcpp_hxt_ignore_allocs(1);
    if (_config.profiler) {
      untyped __global__.__hxcpp_hxt_stash_telemetry();
    }
    _writer.sendMessage({"dump":true, "thread_num":_thread_num});

    // TODO: only send if they change, track locally
    // TODO: support other names, reserved, etc
    var gctotal:Int = Std.int((untyped __global__.__hxcpp_gc_reserved_bytes())/1024);
    var gcused:Int = Std.int((untyped __global__.__hxcpp_gc_used_bytes())/1024);
    _writer.sendMessage({"name":".mem.total","value":gctotal });
    _writer.sendMessage({"name":".mem.used","value":gcused });

    // var gctime:Int = untyped __global__.__hxcpp_hxt_dump_gctime();
    // if (gctime>0) {
    //   _writer.sendMessage({"name":Timing.GC,"delta":gctime,"span":gctime});
    // }

    untyped __global__.__hxcpp_hxt_ignore_allocs(-1);
#end

    // Special-case frame delimiter
    send_frame_delimiter();
  }

  var _last = timestamp_us();
  var _activity_stack:Array<ActivityStackElem> = [];
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
    _activity_stack.push({name:name, t0:t});
    _hier_name += name;
  }

  public function end_timing(name:String):Void
  {
    if (_writer==null) return;

#if cpp
    untyped __global__.__hxcpp_hxt_ignore_allocs(1);
#end
    var t:Float = timestamp_us();
    var data:Dynamic = {"name":_hier_name,"delta":Std.int(t-_last)}
    var top = _activity_stack.pop();
		if (top!=null && top.name==name) {
			data.span = Std.int(t-top.t0);
			_writer.sendMessage(data);
      _hier_name = _hier_name.substr(0, _hier_name.length-name.length);
		} else {
			telemetry_error("WARNING: Inconsistent start/end timing, stack expected "+name+" but got "+top);
		}

    _last = t;
#if cpp
    untyped __global__.__hxcpp_hxt_ignore_allocs(-1);
#end
  }

  private var _restart:Array<String> = [];
  public function send_frame_delimiter():Void
  {
    if (_writer==null) return;

#if cpp
    untyped __global__.__hxcpp_hxt_ignore_allocs(1);
#end
    var t:Float;

    // Stop/restart items still in stack
		while (_activity_stack.length>0) {
			var cur = _activity_stack[_activity_stack.length-1].name;
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
#if cpp
    untyped __global__.__hxcpp_hxt_ignore_allocs(-1);
#end
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


    @:functionCode('
//printf("Dumping telemetry from thread %d\\n", thread_num);
TelemetryFrame* frame = __hxcpp_hxt_dump_telemetry(thread_num);
//printf("Num samples %d\\n", frame->samples->size());

// printf("Dumped telemetry, samples=%d, names=%d, allocs=%d, collections=%d\\n",
//         frame->samples->size(),
//         frame->names->size(),
//         frame->allocations->size(),
//   			frame->collections->size());

int i=0;
int size;
if (frame->samples!=0) {

  // Write names
  if (frame->names->size()>0) {
    output->writeByte(10);
    output->writeInt32(frame->names->size());
    i = 0;
    size = frame->names->size();
    while (i<size) {
      String s = String(frame->names->at(i++));
      output->writeInt32(s.length);
      output->writeString(s);
    }
  }

  // Write samples
  if (frame->samples->size()>0) {
    output->writeByte(11);
    output->writeInt32(frame->samples->size());
    i = 0;
    size = frame->samples->size();
    while (i<size) {
      output->writeInt32(frame->samples->at(i++));
    }
  }

}

if (frame->allocation_data!=0) {

  // Write stacks
  if (frame->stacks->size()>0) {
    output->writeByte(12);
    output->writeInt32(frame->stacks->size());
    i = 0;
    size = frame->stacks->size();
    while (i<size) {
      output->writeInt32(frame->stacks->at(i++));
    }
  }

  // Write allocations
  if (frame->allocation_data->size()>0) {
    // printf(\" -- writing allocs: %d\\n\", frame->allocation_data->size());
    output->writeByte(13);
    output->writeInt32(frame->allocation_data->size());
    i = 0;
    size = frame->allocation_data->size();
    while (i<size) {
      output->writeInt32(frame->allocation_data->at(i++));
    }
  }
}

// GC time
hx::Anon gct = hx::Anon_obj::Create();
gct->Add(HX_CSTRING("name") , HX_CSTRING(".gc"),false);
gct->Add(HX_CSTRING("delta") , (int)frame->gctime,false);
gct->Add(HX_CSTRING("span") , (int)frame->gctime,false);
safe_write(gct);

')
    private static function dump_hxt(thread_num:Int,
                                     output:haxe.io.Output,
                                     safe_write:Dynamic->Void) {
      //safe_write({"name":Timing.GC,"delta":0, "span":0});

      //for (i in 0...arr.length) {
      //  trace(arr[i]);
      //}

      // Examples
      //output.writeString("From haxe!");
      //output.writeInt32(12);
      //output.writeByte(45);
      // var arr:Array<UInt> = new Array<UInt>();
      // arr.push(2);
			// arr.push(4);
      // trace(arr.length);
      //  
      // var foo:Dynamic = {};
      // foo.n = 12;
      // foo.flt = 1.23;
      // foo.samples = new Array<Int>();
      // foo.im = new haxe.ds.IntMap<Dynamic>();
      // foo.im[12] = { type:"String", stackid:12, size:85, ids:(new Array<Int>()) };

      //untyped __global__.__hxcpp_hxt_ignore_allocs(1);
      // 
      //var frameData:Dynamic = untyped __global__.__hxcpp_hxt_dump_telemetry(thread_num);
      // 
      //// These are too large, they crash serializer...
      //Reflect.setField(frameData, "allocations", null);
      //Reflect.setField(frameData, "collections", null);
      // 
      //var b = haxe.io.Bytes.alloc(128);
      //b.set(0, 10);
      //b.set(1, 11);
      // 
      //var bd = new haxe.io.BytesData();
      //bd.blit();
      // 
      //var msg:String = haxe.Serializer.run(frameData);
      // 
      //trace(msg.length);
      // 
      //untyped __global__.__hxcpp_hxt_ignore_allocs(-1);

    }

  private static function start_writer():Void
  {
    var socket:Socket = null;
    var writer:Amf3Writer;

    var hxt_thread:Thread = Thread.readMessage(true);
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

    function safe_write(data:Dynamic) {
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
    mutex.acquire();

    var connected = false;
    var retries = 3;
    function try_connect() {
      socket = new Socket();
      try {
        socket.connect(new sys.net.Host(host), port);
        if (amf_mode) {
          writer = new Amf3Writer(socket.output);
        }
        safe_write({"name":".swf.name","value":app_name, "hxt":switch_to_nonamf,"activity_descriptors":activity_descriptors});
        if (switch_to_nonamf) {
          amf_mode = false;
          writer = null;
        } else {
          mutex.release();
          throw "HXTelemetry no longer supports amf mode!";
        }
        connected = true;
      } catch (e:Dynamic) { }
    }

    while (true) {
      try_connect();
      if (connected) {
        hxt_thread.sendMessage(true);
        break;
      } else if (--retries == 0) {
        trace("HxTelemetry failed to connect to "+host+":"+port);
        hxt_thread.sendMessage(false);
        break;
      } else {
        Sys.sleep(0.1);
      }
    }

    mutex.release();

    while (true) {
      // TODO: Accept timing data, too
      var data:Dynamic = Thread.readMessage(true);
      if (data.dump) {
        var thread_num:Int = data.thread_num;
        //trace("Calling dump telemetry with thread_num: "+thread_num+", socket.output="+socket.output);
        // TODO: @:function cpp dump telemetry, write to socket?  Read directly from cpp data structure?

        untyped __global__.__hxcpp_hxt_ignore_allocs(1);

        dump_hxt(thread_num, socket.output, safe_write);

        //untyped __global__.__hxcpp_hxt_dump_telemetry(thread_num, socket.output);
        //Reflect.setField(frameData, "allocations", null);
        //Reflect.setField(frameData, "collections", null);
        //safe_write(frameData);

        untyped __global__.__hxcpp_hxt_ignore_allocs(-1);
      } else {
        safe_write(data);
        if (data.exit) {
          cleanup();
        }
      }
    }
    trace("HXTelemetry socket thread exiting");
  }
}
