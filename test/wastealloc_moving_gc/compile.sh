rm export/Main-debug; haxe Main.hx -main Main -debug -D HXCPP_STACK_TRACE -D HXCPP_TELEMETRY -D HXCPP_GC_MOVING -cpp export -cp ../.. && ./export/Main-debug
