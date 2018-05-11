package hxtelemetry;

class FrameworkSupport
{

  /**
   * Framework support of hxtelemetry is "in progress". Various
   * frameworks (and even various versions thereof) may implement
   * specific logic to support hxtelemetry. In lieu of support
   * built into the framework, we do what we can here to augment
   * frameworks
   *
   * Let's get hxtelemetry working everywhere. Feel free to submit
   * PR's here or in the framerworks themselves. ;)
   */
  public static function auto(cfg:hxtelemetry.HxTelemetry.Config)
  {
    #if (openfl && !nme)
      // TODO: copy from cfg
      openfl.profiler.Telemetry.config.app_name = "OpenFL App";
			openfl.profiler.Telemetry.config.allocations = true;
    #elseif nme
      NME.augment(cfg);
    #else
      trace('No hxtelemetry.FrameworkSupport detected...');
    #end
  }
}

#if nme

class NME
{
  // nme doesn't have any built-in support, so just add an ENTER_FRAME listener
  public static function augment(cfg:hxtelemetry.HxTelemetry.Config)
  {
    // Hmm, throws at haxe.Timer.stamp() unless I wait here...
    haxe.Timer.delay(function() {
      var hxt = new hxtelemetry.HxTelemetry(cfg);
      nme.Lib.current.stage.addEventListener(nme.events.Event.ENTER_FRAME, function(_) {
        hxt.advance_frame(); // Somehow time is measured as 1000x faster
      });
    }, 1000);
  }
}
#end
