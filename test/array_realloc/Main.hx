package;

class Main {

  static function main() {
    trace("Start...");
    var cfg = new hxtelemetry.HxTelemetry.Config();
    cfg.allocations = true;
    var hxt = new hxtelemetry.HxTelemetry(cfg);

    var array:Array<String> = [];

    var frame:Int = 0;

    var t0 = Sys.time();
    while (Sys.time()-t0 < 30) {
      frame++;
      if (frame<50) {
        //if (frame%5==0) array = [];
        for (i in 0...1000) {
          array.push(i+" is a number");
        }
      } else break;
      //if (frame%100==0) {
      //  trace(" at frame "+frame+", len="+array.length+", bytes="+(array.length*4)+" t="+Sys.time());
      //}
      Sys.sleep(0.1);
      hxt.advance_frame();
    }
    trace("Exit ("+(frame/(Sys.time()-t0))+" fps avg)");

    Sys.sleep(3);
    trace("Goodbye");
  }
}
