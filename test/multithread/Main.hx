package;

import cpp.vm.Thread;

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

class Square extends Rectangle {
  public function new(x,y,s):Void {
    super(x,y,s,s);
  }
}

class Main {

  static function main() {
    trace("Starting threads...");
    var t1 = Thread.create(start);
    t1.sendMessage(1);
    var t2 = Thread.create(start);
    t2.sendMessage(2);
    Sys.sleep(3);
    t1.sendMessage(true);
    t2.sendMessage(true);
    Sys.sleep(0.5);
    trace("Goodbye!");
  }

  static function start() {
    var cfg = new hxtelemetry.HxTelemetry.Config();
    //cfg.allocations = false;
    var idx:Int = Thread.readMessage(true);
    cfg.app_name = "Thread"+idx;
    var hxt = new hxtelemetry.HxTelemetry(cfg);

    var refs:Array<Rectangle> = [];

    // Work on each frame
    var frame:Int = 0;

    var t0 = Sys.time();
    while (!(Thread.readMessage(false)==true)) {
      frame++;
      for (i in 0...1000) {
        //refs.push(i);
        if (idx==1) {
          refs.push(new Rectangle(Std.random(1000)/1000,
                                  Std.random(1000)/1000,
                                  Std.random(1000)/1000,
                                  Std.random(1000)/1000));
        } else {
          refs.push(new Square(Std.random(1000)/1000,
                               Std.random(1000)/1000,
                               Std.random(1000)/1000));
        }
      }
      if (frame%30==0) {
        refs = [];
        trace(cfg.app_name+": at frame "+frame+", t="+Sys.time());
      }
      hxt.advance_frame();
      Sys.sleep(0.016);
    }
    trace("Exit "+cfg.app_name+" ("+(frame/(Sys.time()-t0))+" fps avg)- waiting a few seconds just in case HXTelemetry socket needs to drain...");
  }
}
