package;

class Rectangle {
  var x:Float;
  var y:Float;
  var width:Float;
  var height:Float;
  public function new(x,y,w,h):Void {
    this.x = x;
    this.y = y;
    this.width = w;
    this.height = h;
  }
}

class Main {

  static function main() {
    trace("Start...");
    var cfg = new hxtelemetry.HxTelemetry.Config();
    //cfg.allocations = false;
    var hxt = new hxtelemetry.HxTelemetry(cfg);

    var refs:Array<Int> = [];

    // Work on each frame
    var frame:Int = 0;

    var t0 = Sys.time();
    while (Sys.time()-t0 < 40) {
      frame++;
      for (i in 0...400) {
        refs.push(i);
        //refs.push(new Rectangle(Std.random(1000)/1000,
        //                        Std.random(1000)/1000,
        //                        Std.random(1000)/1000,
        //                        Std.random(1000)/1000));
      }
      //if (frame%10==0) {
      //  refs = [];
      //  trace(" at frame "+frame+", t="+Sys.time());
      //}
      hxt.advance_frame(); // Somehow time is measured as 1000x faster
      var a = 0;
      //for (i in 0...30000000) { if (refs.length>i) refs[i] = null; }
      //untyped __global__.__hxcpp_collect(true); // Causes object ID collisions!
      Sys.sleep(0.033);
    }
    trace("Exit ("+(frame/(Sys.time()-t0))+" fps avg)- waiting a few seconds just in case HXTelemetry socket needs to drain...");

    Sys.sleep(2);
    trace("Goodbye");
  }
}
