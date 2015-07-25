package;

import haxe.ds.IntMap;

import hxtelemetry.HxTelemetry.Timing;

class Main {

  static function main() {
    trace("Start...");
    trace(Date.now().getTime());
    trace(haxe.Timer.stamp());
    var cfg = new hxtelemetry.HxTelemetry.Config();
    //cfg.allocations = false;
    var hxt = new hxtelemetry.HxTelemetry(cfg);

    Sys.sleep(0.033); hxt.advance_frame(); // frame 1
    Sys.sleep(0.033); hxt.advance_frame(); // frame 2

    //hxtelemetry.Singleton.start_timing(Timing.USER);
    Sys.sleep(0.005); // 5ms user time
    //hxtelemetry.Singleton.end_timing(Timing.USER);
    
    Sys.sleep(0.033-0.005); hxt.advance_frame(); // frame 3
    Sys.sleep(0.033); hxt.advance_frame(); // frame 4
    Sys.sleep(0.033); hxt.advance_frame(); // frame 5
    Sys.sleep(0.033); hxt.advance_frame(); // frame 6
    Sys.sleep(0.033); hxt.advance_frame(); // frame 7
    Sys.sleep(0.033); hxt.advance_frame(); // frame 8
    Sys.sleep(0.033); hxt.advance_frame(); // frame 9
    Sys.sleep(0.033); hxt.advance_frame(); // frame 10

    trace("Goodbye");
  }
}
