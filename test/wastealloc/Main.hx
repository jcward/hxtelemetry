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

    var refs:Array<Rectangle> = [];

    // Work on each frame
    var frame:Int = 0;

    var t0 = Sys.time();
    while (Sys.time()-t0 < 4) {
      frame++;
      for (i in 0...2000) {
        refs.push(new Rectangle(Std.random(1000)/1000,
                                Std.random(1000)/1000,
                                Std.random(1000)/1000,
                                Std.random(1000)/1000));
      }
      if (frame%10==0) {
        refs = [];
        trace(" at frame "+frame+", t="+Sys.time());
      }
      hxt.advance_frame();
    }
    trace("Exit ("+(frame/(Sys.time()-t0))+" fps avg)- waiting a few seconds just in case HXTelemetry socket needs to drain...");

    Sys.sleep(3);
    trace("Goodbye");
  }
}
