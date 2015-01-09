package;


import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.utils.ByteArray;
import openfl.Assets;


class Main extends Sprite {
	
	
	public function new () {
		
		super ();
		
		var bitmap = new Bitmap (Assets.getBitmapData ("assets/openfl.png"));
		addChild (bitmap);
		
		bitmap.x = (stage.stageWidth - bitmap.width) / 2;
		bitmap.y = (stage.stageHeight - bitmap.height) / 2;

    test_profalloc();
  }

  static function test_profalloc()
  {
    var flm = new hxflm.HxFLM();

    var frame:Int = 0;
    flash.Lib.stage.addEventListener(openfl.events.Event.ENTER_FRAME, function(e) {
        frame++;

        flm.start_timing(".as.doactions");
        if (frame%15==5) TestTimeWaster.foo_a();
        if (frame%15==10) TestTimeWaster.foo_b();
        if (frame%15==0) TestTimeWaster.clear();
        flm.end_timing(".as.doactions");
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
      while (j++<1000000) { i++; }
    }
    alloc_1mb_64strings();
  }

  public static function self_8ms_total_16ms_4mb():Void
  {
    var t0:Float = Util.getTimer();
    var i:Int = 0;
    var j:Int = 0;
    while (Util.getTimer()-t0 < 8) {
      while (j++<10000) { i++; }
    }
    for (i in 0...4) self_2ms_1mb();
  }

  public static function self_2ms_total_8ms_3mb():Void
  {
    var t0:Float = Util.getTimer();
    var i:Int = 0;
    var j:Int = 0;
    while (Util.getTimer()-t0 < 2) {
      while (j++<100000) { i++; }
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
