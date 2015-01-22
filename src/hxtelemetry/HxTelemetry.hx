package hxtelemetry;

import sys.net.Socket;
import amf.io.Amf3Writer;
import haxe.ds.StringMap;

class Config
{
  public var app_name:String = "My App";
  public var telemetry_host:String = "localhost";
  public var socket_port:Int = 7934;
  public var auto_event_loop:Bool = true;
  public var cpu_usage:Bool = true;
  public var profiler:Bool = true;
  public var alloc:Bool = true;
  public var singleton_instance:Bool = true;
}

class Timing {
  // Couldn't get an enum to work well wrt scope/access, still needed toString() anyway

  // Scout compatibility issue - real names
  public static inline var GC:String = ".gc.custom";
  public static inline var USER:String = ".as.doactions";
  public static inline var RENDER:String = ".rend.custom";
  public static inline var OTHER:String = ".other.custom";
  public static inline var NET:String = ".net.custom";
  public static inline var ENTER:String = ".enter";
  // CUSTOM(s:String, color:Int); // TODO: implement me? Sounds cool!
}

class HxTelemetry
{
  // Optional: singleton accessors
  public static var singleton(default,null):HxTelemetry;

  // Member objects
  var _socket:Socket;
  var _writer:Amf3Writer;
  var _config:Config;

  // Timing helpers
  static var _abs_t0_usec:Float = Date.now().getTime()*1000;
  static inline function timestamp_ms():Float { return _abs_t0_usec/1000 + haxe.Timer.stamp()*1000; };
  static inline function timestamp_us():Float { return _abs_t0_usec + haxe.Timer.stamp()*1000000; };

  public function new(config:Config=null)
  {
    if (config==null) config = new Config();
    _config = config;

    if (_config.singleton_instance) {
      if (singleton!=null) throw "Cannot have two singletons of HxTelemetry!";
      singleton = this;
    }

    if (!setup_socket(config.telemetry_host, config.socket_port)) return;

#if cpp
    if (_config.alloc && !_config.profiler) {
      throw "HxTelemetry config.alloc requires config.profiler";
    }

    if (_config.profiler) {
      untyped __global__.__hxcpp_start_telemetry();
    }
#end

    if (config.auto_event_loop) setup_event_loop();
  }

  function setup_socket(host:String, port:Int):Bool
  {
    _socket = new Socket();
    try {
      _socket.connect(new sys.net.Host(host), port);
      _method_names = new Array<String>();
      _samples = new Array<Int>();
      _alloc_types = new Array<String>();
      _alloc_details = new Array<Int>();

      _writer = new Amf3Writer(_socket.output);
      write_preamble();
      return true;
    } catch (e:Dynamic) {
      trace("Failed connecting to Telemetry host at "+host+":"+port);
      return false;
    }
  }

  function write_preamble()
  {
    if (_writer!=null) {
      _writer.write({"name":".swf.name","value":_config.app_name});

      // Scout compatibility issue
      //try {
      //  _writer.write({"name":".tlm.version","value":"3,2"});
      //  _writer.write({"name":".tlm.meta","value":0});
      //  _writer.write({"name":".tlm.date","value":Std.int(timestamp_ms())});
      //  _writer.write({"name":".player.version","value":"13,0,0,182"});
      //  _writer.write({"name":".player.airversion","value":"13.0.0.83"});
      //  _writer.write({"name":".player.type","value":"Air"});
      //  _writer.write({"name":".player.debugger","value":true});
      //  _writer.write({"name":".player.global.date","value":Std.int(timestamp_ms())});
      //  _writer.write({"name":".player.instance","value":0});
      //  _writer.write({"name":".player.scriptplayerversion","value":24});
      //  _writer.write({"name":".platform.capabilities","value":"&M=Adobe Windows&R=2560x1440&COL=color&AR=1.0&OS=Windows XP 64&ARCH=x86&L=en&IME=f&PR32=t&PR64=t&LS=en-US"});
      //  _writer.write({"name":".platform.cpucount","value":4});
      //  _writer.write({"name":".mem.total","value":1033});
      //  _writer.write({"name":".mem.used","value":181});
      //  _writer.write({"name":".mem.managed","value":100});
      //  _writer.write({"name":".mem.managed.used","value":18});
      //  _writer.write({"name":".mem.telemetry.overhead","value":5});
      //  _writer.write({"name":".tlm.category.disable","value":"3D"});
      //  _writer.write({"name":".tlm.category.disable","value":"sampler"});
      //  _writer.write({"name":".tlm.category.disable","value":"displayobjects"});
      //  _writer.write({"name":".tlm.category.disable","value":"alloctraces"});
      //  _writer.write({"name":".tlm.category.disable","value":"allalloctraces"});
      //
      //  start_timing(".swf.parse");
      //  start_timing(".gc.Reap");
      //  end_timing(".gc.Reap");
      //
      //  _writer.write({"name":".network.loadmovie","value":"app:/Main.swf"});
      //  _writer.write({"name":".player.view.resize","value":{"xmax":1798,"xmin":0,"ymax":1011,"ymin":0}});
      //  _writer.write({"name":".swf.size","value":1533});
      //  end_timing(".swf.parse");
      //  _writer.write({"name":".swf.debug","value":true});
      //
      //  _writer.write({"name":".tlm.category.start","value":"customMetrics"});
      //  _writer.write({"name":".tlm.detailedMetrics.start","value":true});
      //  _writer.write({"name":".swf.size","value":2018});
      //  _writer.write({"name":".swf.parse","span":1,"delta":1});
      //  _writer.write({"name":".as.doactions","span":1,"delta":1});
      //  _writer.write({"name":".swf.globalobject","span":1,"delta":1,"value":"https://www.macromedia.com/support/flashplayer/sys/"});
      //
      //  _writer.write({"name":".player.abcdecode","span":1,"delta":1});
      //  _writer.write({"name":".starttimer","value":2});
      //  _writer.write({"name":".swf.start","delta":1});
      //  _writer.write({"name":".swf.name","value":_config.app_name});
      //  _writer.write({"name":".swf.rate","value":16667});
      //  _writer.write({"name":".swf.vm","value":3});
      //  _writer.write({"name":".swf.width","value":640});
      //  _writer.write({"name":".swf.height","value":480});
      //  _writer.write({"name":".swf.playerversion","value":18});
      //  _writer.write({"name":".swf.displayname","value":"Example"});
      //  _writer.write({"name":".player.view.resize","value":{"xmax":640,"xmin":0,"ymax":480,"ymin":0}});
      //  _writer.write({"name":".gc.Reap","span":1,"delta":1});
      //  _writer.write({"name":".as.doactions","span":1,"delta":1});
      //  _writer.write({"name":".as.actions","span":1,"delta":484});
      //  _writer.write({"name":".as.event","span":1,"delta":1,"value":"status"});
      //  _writer.write({"name":".as.event","span":1,"delta":1,"value":"complete"});
      //  _writer.write({"name":".network.swf.received","span":1,"delta":1,"value":1237});
      //  _writer.write({"name":".network.loader.receive","span":1,"delta":1,"value":5});
      //  _writer.write({"name":".network.loader.receive","span":1,"delta":1,"value":5});
      //  _writer.write({"name":".network.loader.close","span":9,"delta":1,"value":5});
      //  _writer.write({"name":".network.loadfile","span":1,"delta":1,"value":"app:/Main.swf"});
      //  _writer.write({"name":".as.runentrypoint","span":1,"delta":1});
      //  _writer.write({"name":".gc.Reap","span":1,"delta":1});
      //  _writer.write({"name":".mem.total","value":7057});
      //  _writer.write({"name":".mem.used","value":6321});
      //  _writer.write({"name":".mem.managed","value":5432});
      //  _writer.write({"name":".mem.managed.used","value":4921});
      //  _writer.write({"name":".tlm.doplay","span":1,"delta":1});

      //} catch (e:Dynamic) {
      //  cleanup();
      //}
    }
  }

  function setup_event_loop():Void
  {
#if openfl
    flash.Lib.stage.addEventListener(openfl.events.Event.ENTER_FRAME, _advance_frame);
#elseif lime
    trace("Does lime have an event loop?");
#else
    trace("TODO: create separate thread for event loop? e.g. commandline tools");
#end
  }

  var _method_names:Array<String>;
  var _samples:Array<Int>;
  var _alloc_types:Array<String>;
  var _alloc_details:Array<Int>;
  function _advance_frame(e=null)
  {
    if (_writer==null) return;

#if cpp
    untyped __global__.__hxcpp_hxt_ignore_allocs(true);
    if (_config.profiler) {
      untyped __global__.__hxcpp_dump_hxt_names(_method_names);
      if (_method_names.length>0) {
        // Scout compatibility issue - wants bytes, not array<string>
        safe_write({"name":".sampler.methodNameMapArray","value":_method_names});
        _method_names = new Array<String>();
      }
      untyped __global__.__hxcpp_dump_hxt_samples(_samples);
      var alloc_samples:Array<Int> = _config.alloc ? [] : null;
      if (_samples.length>0) {
        var i:Int=0;
        while (i<_samples.length) {
          var depth = _samples[i++];
          if (_config.alloc) alloc_samples.push(depth);
          var callstack:Array<Int> = new Array<Int>();
          for (j in 0...depth) {
            if (_config.alloc) alloc_samples.push(_samples[depth-1+i-2*j]);
            callstack.unshift(_samples[i++]);
          }
          var delta = _samples[i++];
          safe_write({"name":".sampler.sample","value":{"callstack":callstack, "numticks":delta}});
        }
        if (_config.alloc) {
          safe_write({"name":".memory.stackIdMap","value":alloc_samples});
        }
        _samples = new Array<Int>();
      }
      if (_config.alloc) {
        untyped __global__.__hxcpp_dump_hxt_allocations(_alloc_types, _alloc_details);
        trace(" -- got "+_alloc_types.length+" allocations, "+_alloc_details.length+" details!");
        if (_alloc_types.length>0) {
          var i:Int=0;
          while (i<_alloc_types.length) {
            var type = _alloc_types[i];
            var id:Int = _alloc_details[i*3];
            var size:Int = _alloc_details[i*3+1];
            var stackid:Int = _alloc_details[i*3+2];
            i++;            
            // Scout compatibility issue - value also includes "time", e.g.
            //  {"name":".memory.newObject","value":{"size":20,"time":72655,"type":"[class Namespace]","id":65268272,"stackid":1}}
            safe_write({"name":".memory.newObject","value":{"size":size, "type":type, "stackid":stackid, "id":id}});
          }
          _alloc_types = new Array<String>();
          _alloc_details = new Array<Int>();
        }
      }
    }
    untyped __global__.__hxcpp_hxt_ignore_allocs(false);
#end

    end_timing(Timing.ENTER);
  }

  var _last = timestamp_us();
  var _start_times:StringMap<Float> = new StringMap<Float>();
  public function start_timing(name:String):Void
  {
    if (_writer==null) return;

    var t = timestamp_us();
    _start_times.set(name, t);
  }
  public function end_timing(name:String):Void
  {
    if (_writer==null) return;

#if cpp
    untyped __global__.__hxcpp_hxt_ignore_allocs(true);
#end
    var t = timestamp_us();
    try {
      if (_start_times.exists(name)) {
        _writer.write({"name":name,"delta":Std.int(t-_last),"span":Std.int(t-_start_times.get(name))});
        _start_times.remove(name);
      } else {
        _writer.write({"name":name,"delta":Std.int(t-_last)});
      }
    } catch (e:Dynamic) {
      cleanup();
    }
    _last = t;
#if cpp
    untyped __global__.__hxcpp_hxt_ignore_allocs(false);
#end
  }

  function safe_write(obj:Dynamic):Void
  {
    if (_writer==null) return;
#if cpp
    untyped __global__.__hxcpp_hxt_ignore_allocs(true);
#end
    try {
      _writer.write(obj);
    } catch (e:Dynamic) {
      cleanup();
    }
#if cpp
    untyped __global__.__hxcpp_hxt_ignore_allocs(false);
#end
  }

  function cleanup()
  {
    if (_socket!=null) {
      _socket.close();
      _socket = null;
    }
    _writer = null;
  }

}
