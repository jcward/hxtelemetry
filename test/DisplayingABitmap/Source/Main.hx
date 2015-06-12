package;


import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.utils.ByteArray;
import openfl.Assets;

#if (telemetry)
  import hxtelemetry.HxTelemetry.Timing;
#end

class Main extends Sprite {

	public static var fps:openfl.display.FPS;

// Configuration still WIP
//   public static var telemetry_config:Bool = (function():Bool {
// #if (cpp && telemetry)
//     if ((Sys.args().length>0 && Sys.args().indexOf('-a')<0)) {
//     openfl.profiler.Telemetry.config.allocations = false;
//     }
//   #if android
//     openfl.profiler.Telemetry.config.host = "10.0.1.33";
//   	openfl.profiler.Telemetry.config.app_name = "Android App";
//   #end
// #end
//   	return true;
//   })();
	
	public function new () {
		
		super ();

    //  trace("Starting telemetry...");
    //  var cfg = new hxtelemetry.HxTelemetry.Config();
    //  //cfg.allocations = false;
//#if android
//		cfg.app_name = "Android App";
//		cfg.host = "10.0.1.33";
//#else
//		cfg.app_name = "Test App";
//#end 
    //  var hxt = new hxtelemetry.HxTelemetry(cfg);
		//   
    //   
    //  Sys.sleep(0.033); hxt.advance_frame(); // frame 1
    //  Sys.sleep(0.033); hxt.advance_frame(); // frame 2
    //   
    //  hxtelemetry.Singleton.start_timing(Timing.USER);
    //  Sys.sleep(0.005); // 5ms user time
    //  hxtelemetry.Singleton.end_timing(Timing.USER);
    //  hxtelemetry.Singleton.start_timing(Timing.RENDER);
    //  Sys.sleep(0.005); // 5ms user time
    //  hxtelemetry.Singleton.end_timing(Timing.RENDER);
    //  Sys.sleep(0.033-0.010); hxt.advance_frame(); // frame 3
    //   
    //  Sys.sleep(0.033); hxt.advance_frame(); // frame 4
    //  Sys.sleep(0.033); hxt.advance_frame(); // frame 5
    //   
    //  hxtelemetry.Singleton.start_timing(Timing.USER);
    //  Sys.sleep(0.005); // 5ms user time
    //  hxtelemetry.Singleton.start_timing(Timing.RENDER);
    //  Sys.sleep(0.005); // 5ms user time
    //  hxtelemetry.Singleton.end_timing(Timing.RENDER);
    //  hxtelemetry.Singleton.end_timing(Timing.USER);
    //  Sys.sleep(0.033-0.010); hxt.advance_frame(); // frame 6
    //   
    //  hxtelemetry.Singleton.start_timing(Timing.USER);
    //  Sys.sleep(0.005); // 5ms user time
    //  hxtelemetry.Singleton.start_timing(Timing.USER+".event_handlers");
    //  Sys.sleep(0.005); // 5ms user time
    //  hxtelemetry.Singleton.end_timing(Timing.USER+".event_handlers");
    //  hxtelemetry.Singleton.start_timing(Timing.USER+".foo");
    //  Sys.sleep(0.005); // 5ms user time
    //  hxtelemetry.Singleton.end_timing(Timing.USER+".foo");
    //  hxtelemetry.Singleton.end_timing(Timing.USER);
    //  Sys.sleep(0.033-0.015); hxt.advance_frame(); // frame 6
    //   
    //  Sys.sleep(0.033); hxt.advance_frame(); // frame 7
    //  Sys.sleep(0.033); hxt.advance_frame(); // frame 8
    //  Sys.sleep(0.033); hxt.advance_frame(); // frame 9
    //  Sys.sleep(0.033); hxt.advance_frame(); // frame 10


    trace("Adding bitmap");
		var bitmap = new Bitmap (Assets.getBitmapData ("assets/openfl.png"));
		addChild (bitmap);
		
		bitmap.x = (stage.stageWidth - bitmap.width) / 2;
		bitmap.y = (stage.stageHeight - bitmap.height) / 2;

		fps = new openfl.display.FPS(0,0);
		fps.mouseEnabled = false;
		stage.addChild(fps);

    trace("Starting shape allocator");
		test_profalloc();
  }

  static function ls():LongStructor
  {
    trace("About to new a LongStructor:");
    return new LongStructor();
  }

  static function test_profalloc()
  {
    var frame:Int = 0;
    var stage = flash.Lib.current.stage;

    trace("Here we go...");

		stage.addEventListener(openfl.events.Event.ENTER_FRAME, function(e) {
				frame++;

        if (frame%10==0) trace("At frame: "+frame);

        function new_bmp() {
          //var bmp = new Bitmap(Assets.getBitmapData ("assets/openfl.png"));
          var bmp = new openfl.display.Shape();
          bmp.graphics.beginFill(Std.random(0xffffff));
          bmp.graphics.drawRoundRect(-20, -10, 40, 20, 7);
          bmp.x = Std.random(stage.stageWidth);
    			bmp.y = Std.random(stage.stageHeight);
          var sc:Float = Std.random(10)/10.0+1.5;
					bmp.scaleX = bmp.scaleY = sc;
          stage.addChild(bmp);
          var dr:Float = Std.random(10)-5;
          var dx:Float = Std.random(10)-5;
          var dy:Float = Std.random(10)-5;
          if (dx<0) dx -= 0.6; else dx += 0.6;
					if (dy<0) dy -= 0.6; else dy += 0.6;
          function anim(e) {
            bmp.x += dx;
            bmp.y += dy;
            bmp.rotation += dr;
            if (bmp.x<-50 || bmp.x > stage.stageWidth+50 ||
                bmp.y<-50 || bmp.y > stage.stageHeight+50) {
              stage.removeChild(bmp);
              stage.removeEventListener(openfl.events.Event.ENTER_FRAME, anim);
            }
          }
          stage.addEventListener(openfl.events.Event.ENTER_FRAME, anim);
        }
        for (i in 0...2) new_bmp();
        stage.addChild(Main.fps);

				//if (frame%20==5) {
        //  var b:ByteArray = new ByteArray();
        //  trace(b.length);
        //}

				// hxt.start_timing(Timing.USER);
				// if (frame%15==5) {
        //   //trace("Longstructor:");
        //   var l = ls();
        //   //trace(l);
        // }
				// hxt.end_timing(Timing.USER);

				//hxtelemetry.Singleton.start_timing(Timing.USER);
				//if (frame%15==5) TestTimeWaster.foo_a();
				//if (frame%15==10) TestTimeWaster.foo_b();
				//if (frame%15==0) TestTimeWaster.clear();
				//hxtelemetry.Singleton.end_timing(Timing.USER);

				//if (frame%15==9) {
        //  hxt.cleanup();
        //  openfl.system.System.exit();
        //}
		});
	}
}

class Util
{
  static var __t0:Float = haxe.Timer.stamp();
  public static function getTimer():Float {
    return (haxe.Timer.stamp()-__t0)*1000;
  }
}

class LongStructor
{
  var foo:Int;

  var _t0:Float;
  var _t1:Float;
  var _t2:Float;
  var _t3:Float;
  var _t4:Float;
  var _t5:Float;
  var _t6:Float;
  var _t7:Float;
  var _t8:Float;
  var _t9:Float;
  var _ta:Float;
  var _tb:Float;
  var _tc:Float;

  var _qt0:Float;
  var _qt1:Float;
  var _qt2:Float;
  var _qt3:Float;
  var _qt4:Float;
  var _qt5:Float;
  var _qt6:Float;
  var _qt7:Float;
  var _qt8:Float;
  var _qt9:Float;
  var _qta:Float;
  var _qtb:Float;
  var _qtc:Float;

  var _arr:Array<Int>;

  public function new() {
    var t0:Float = Util.getTimer();
    var i:Int = 0;
    var j:Int = 0;
    //while (Util.getTimer()-t0 < 20) {
    //  while (j++<10000000) { i++; }
    //}
    trace("I am in the constructor of LongStructor and I think I'm quite a few bytes in length! "+Math.random());
    foo = i + j;

    fill();
  }

  private function fill()
  {
    trace("About to fill...");
    _arr = new Array<Int>();
    for (i in 0...10000) {
      _arr.push(i);
    }
    trace("All full!");
  }
}

class TestTimeWaster
{
  static var _ref:Array<Dynamic> = [];

  // self 3, total 3+2+16+8, alloc 1+4+1+4=10mb, 
  public static function foo_a():Void
  {
    var t0:Float = Util.getTimer();
    var i:Int = 0;
    var j:Int = 0;
    while (Util.getTimer()-t0 < 3) {
      while (j++<1000000) { i++; }
    }

    self_2ms_1mb();
    self_8ms_total_16ms_4mb();
    alloc_1mb_64strings();
    foo_b();
  }

  // self 0, total 8ms, alloc 4mb
  public static function foo_b():Void
  {
    alloc_1mb_64strings();
    self_2ms_total_8ms_3mb();
  }

  public static function clear():Void
  {
    _ref = [];
  }

  public static function self_2ms_1mb():Void
  {
    var t0:Float = Util.getTimer();
    var i:Int = 0;
    var j:Int = 0;
    while (Util.getTimer()-t0 < 2) {
      j = 0; while (j++<100000) { i++; }
    }
    alloc_1mb_64strings();
  }

  public static function self_8ms_total_16ms_4mb():Void
  {
    var t0:Float = Util.getTimer();
    var i:Int = 0;
    var j:Int = 0;
    while (Util.getTimer()-t0 < 8) {
      j = 0; while (j++<100000) { i++; }
    }
    for (i in 0...4) self_2ms_1mb();
  }

  public static function self_2ms_total_8ms_3mb():Void
  {
    var t0:Float = Util.getTimer();
    var i:Int = 0;
    var j:Int = 0;
    while (Util.getTimer()-t0 < 2) {
      j = 0; while (j++<100000) { i++; }
    }
    for (i in 0...3) self_2ms_1mb();
  }

  public static function alloc_1mb_64strings():Void
  {
    var b:ByteArray = new ByteArray(1024*1024);
    //b.length = 1024*1024;
    b.position = 1024*1024 - 1;
    b.writeByte(1);
    _ref.push(b);
    alloc_64_strings();
  }

  public static function alloc_64_strings():Void
  {
    for (i in 0...64) {
      _ref.push(i+" <--- a string is a string is a string, and by any other name, still a string!");
    }
  }

}
