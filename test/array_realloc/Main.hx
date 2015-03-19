package;

class Main {

  static function main() {
    trace("Start...");
    var cfg = new hxtelemetry.HxTelemetry.Config();
    //cfg.allocations = false;
    var hxt = new hxtelemetry.HxTelemetry(cfg);

    var array:Array<String> = [];

    var frame:Int = 0;

    var t0 = Sys.time();
    while (Sys.time()-t0 < 2) {
      frame++;
      for (i in 0...10) {
        array.push("i like "+i);
      }
      if (frame%100==0) {
        trace(" at frame "+frame+", len="+array.length+", t="+Sys.time());
      }
      if (frame%1000==0) { return; } // debug
      hxt.advance_frame();
    }
    trace("Exit ("+(frame/(Sys.time()-t0))+" fps avg)- waiting a few seconds just in case HXTelemetry socket needs to drain...");

    Sys.sleep(3);
    trace("Goodbye");
  }
}
