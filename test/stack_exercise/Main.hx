// Creates allocations with randomized call stacks (hence, increasing stack ID's)
package;

class Point {
  var x:Float;
  var y:Float;
  public function new(x,y):Void {
    this.x = x;
    this.y = y;
  }
}

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

  static function new_rect():Rectangle {
    return new Rectangle(Std.random(1000)/1000,
                         Std.random(1000)/1000,
                         Std.random(1000)/1000,
                         Std.random(1000)/1000);
  }

  static function new_point():Point {
    return new Point(Std.random(1000)/1000,
                     Std.random(1000)/1000);
  }

  static function random0():Dynamic {
    var rnd = Std.random(4);
    if (rnd==0) return random0();
    if (rnd==1) return random1();
    if (rnd==2) return new_rect();
    return new_point();
  }

  static function random1():Dynamic {
    var rnd = Std.random(4);
    if (rnd==0) return random0();
    if (rnd==1) return random1();
    if (rnd==2) return new_rect();
    return new_point();
  }

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
      for (i in 0...2 /* 2000 */) {
        refs.push(random0());
        refs.push(random1());
      }
      if (frame%10==0) {
        break;
        refs = [];
        trace(" at frame "+frame+", t="+Sys.time());
      }
      hxt.advance_frame();
    }
    trace("Exit ("+(frame/(Sys.time()-t0))+" fps avg)- waiting a few seconds just in case HXTelemetry socket needs to drain...");

    Sys.sleep(1);
    trace("Goodbye");
  }
}
