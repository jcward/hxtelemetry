package hxtelemetry;

class Singleton
{
  public static inline function start_timing(name:String) {
    if (hxtelemetry.HxTelemetry.singleton!=null) {
      hxtelemetry.HxTelemetry.singleton.start_timing(name);
    }
  }
  public static inline function end_timing(name:String) {
    if (hxtelemetry.HxTelemetry.singleton!=null) {
      hxtelemetry.HxTelemetry.singleton.end_timing(name);
    }
  }
}
