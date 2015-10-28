package hxtelemetry;

//  public inline static function validate_config(hxt:HxTelemetry):Void
//  public inline static function start_profiler(hxt:HxTelemetry):Int
//  public inline static function disable_alloc_tracking(disabled:Bool):Void
//  public static function do_advance_frame(hxt:HxTelemetry):Void
//  public static function dump_telemetry_frame(thread_num:Int,
//                                              output:haxe.io.Output,
//                                              write_object:Dynamic->Void) {}

class NekoHxTelemetry
{

  public inline static function validate_config(hxt:HxTelemetry):Void
  {
  }

  public inline static function start_profiler(hxt:HxTelemetry):Int
  {
    return 0;
  }

  public static function do_advance_frame(hxt:HxTelemetry):Void
  {
  }

  public inline static function disable_alloc_tracking(set_disabled:Bool):Void
  {
  }

  public static function dump_telemetry_frame(thread_num:Int,
                                              output:haxe.io.Output,
                                              write_object:Dynamic->Void) {}

}
