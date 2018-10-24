hxtelemetry
===========

hxtelemetry is an application profiling library that enables telemetry generation
for hxScout from Haxe C++ applications. The telemetry provided consists of timing
information, callstack samples, and object allocation and garbage collection data.

See [hxscout.com](http://hxscout.com) for more details.

CI / Compatibility
==================

<img src="https://travis-ci.com/jcward/hxtelemetry.svg?branch=master">

The CI tests the following configurations on linux64:

- Haxe 3.2.1 /w hxcpp 3.2.193
- Haxe 3.4.7 /w hxcpp 3.4.220
- Haxe 4.0.0-preview.5 /w hxcpp 4.0.7
