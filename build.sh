#!/bin/bash

mkdir build
cd ..
zip -r ndls/build/complete-source-code.zip ndls/ -x "ndls/.git/*" "ndls/lib/doc/*" "ndls/build.sh" "ndls/build/*"
