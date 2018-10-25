#!/bin/bash
# expected to be run from hxtelemetry directory, e.g. ./ci/test_wastealloc.sh

# Die immediately if any command fails
set -e

haxelib dev hxtelemetry .
cd test/wastealloc

# Build
haxe Main.hx -main Main -debug -D HXCPP_STACK_TRACE -D HXCPP_TELEMETRY -cpp export -lib hxtelemetry

if [[ "$OS" == "Windows_NT" ]]; then
  # Windows (travis cygwin) doesn't have netcat, just run the test, don't check for output
  ./export/Main-debug
else
  # Background process to capture .hxt data to a file
  nc -l 0.0.0.0 7934 > data.hxt &

  sleep 0.1
  ./export/Main-debug
  sleep 0.1

  # Ensure data.hxt is larger than 1000 bytes
  SIZE=$(du -sb data.hxt | awk '{ print $1 }')

  if ((SIZE>1000)) ; then 
    echo "Telemetry data captured successfully - $SIZE bytes"; 
  else 
    echo "ERROR: Telemetry data NOT captured!"; 
    exit 1
  fi
fi
