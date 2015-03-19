package;

class Main {

  static function main() {
    trace("Start...");
    var cfg = new hxtelemetry.HxTelemetry.Config();
    cfg.allocations = true;
    var hxt = new hxtelemetry.HxTelemetry(cfg);

    var array:Array<Int> = [];

    var frame:Int = 0;

    var t0 = Sys.time();
    while (Sys.time()-t0 < 2) {
      frame++;
      for (i in 0...100000) {
        array.push(i);
      }
      if (frame%100==0) {
        trace(" at frame "+frame+", len="+array.length+", bytes="+(array.length*4)+" t="+Sys.time());
      }
      if (frame%1000==0) { break; } // debug
      Sys.sleep(0.1);
      hxt.advance_frame();
    }
    trace("Exit ("+(frame/(Sys.time()-t0))+" fps avg)");

    Sys.sleep(3);
    trace("Goodbye");
  }
}
