package;

import haxe.ds.IntMap;

class Main {

  static function main() {
    trace("Start...");
    var cfg = new hxtelemetry.HxTelemetry.Config();
    //cfg.allocations = false;
    var hxt = new hxtelemetry.HxTelemetry(cfg);

    var big_map:IntMap<String> = new IntMap<String>();
    var foo = "Hello world!";

    // Work on each frame
    var frame:Int = 0;

    var t0 = Sys.time();
    while (Sys.time()-t0 < 40) {
      frame++;
      for (i in 0...500) {
        var i = Std.random(0x7FFFFFFF);
        big_map.set(i, foo);
      }
      hxt.advance_frame(); // Somehow time is measured as 1000x faster
      var a = 0;
      Sys.sleep(0.033);
    }
    trace("Exit ("+(frame/(Sys.time()-t0))+" fps avg)- waiting a few seconds just in case HXTelemetry socket needs to drain...");

    Sys.sleep(2);
    trace("Goodbye");
  }
}
