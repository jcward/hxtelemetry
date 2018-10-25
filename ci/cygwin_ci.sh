#!/bin/bash

set -e

# Setup

alias save_export=export
mkdir -p /opt/
source $TRAVIS_BUILD_DIR/ci/setup.neko.source
source $TRAVIS_BUILD_DIR/ci/setup.haxe-3.4.7.source
$TRAVIS_BUILD_DIR/ci/setup.hxcpp.sh 3.4.220

neko -version
haxe -version

# Test

cd $TRAVIS_BUILD_DIR && ./ci/test_wastealloc.sh
