Since HaxeFlixel is run under OpenFL, there is no setup required.
All you need to do is make sure you have the required library
versions (OpenFL >= 3.1.1, HxTelemetry, hxcpp >= 3.2.171) and
add `-Dtelemetry` to your command, e.g.

`openfl test windows -Dtelemetry`

Keep in mind the telemetry only works for cpp platforms (windows, mac, linux, ios, android, etc) and not neko, html, or other non-cpp platforms.
