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

  static inline function setTimeout(f:Void->Void, d:Int):Void {
    haxe.Timer.delay(f, d);
  }
  static var __t0:Float = haxe.Timer.stamp();
  public static function getTimer():Float {
    return Sys.time();
    //return (haxe.Timer.stamp()-__t0)*1000;
  }

  static function main() {
    trace("Start...");
    var cfg = new hxtelemetry.HxTelemetry.Config();
    cfg.allocations = false;
    var hxt = new hxtelemetry.HxTelemetry(cfg);

    var refs:Array<Rectangle> = [];

    // Work on each frame
    var frame:Int = 0;

    var t0 = getTimer();
    while (getTimer()-t0 < 4) {
      frame++;
      for (i in 0...2000) {
        refs.push(new Rectangle(Std.random(1000)/1000,
                                Std.random(1000)/1000,
                                Std.random(1000)/1000,
                                Std.random(1000)/1000));
      }
      if (frame%10==0) {
        refs = [];
        trace(" at frame "+frame+", t="+getTimer());
      }
      hxt.advance_frame();
    }
    trace("Exit ("+(frame/(getTimer()-t0))+" fps avg)- is it possible to wait for HXTelemetry socket to drain?");
  }
}
