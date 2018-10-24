#!/bin/bash

VER=$1
echo "Installing hxcpp-$VER"

cd /opt/
curl http://nmehost.com/releases/hxcpp/hxcpp-$VER.zip > tmp.zip
unzip tmp.zip
rm tmp.zip
haxelib dev hxcpp /opt/hxcpp*
