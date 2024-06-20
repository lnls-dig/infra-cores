#!/bin/sh

set -e

for tb in ./*/nvc/; do
	echo "Testbench ${tb}"
	cd "$tb"
	hdlmake
	make clean
	make
	cd ../../
done

for tb in ./*/*/nvc/; do
	echo "Testbench ${tb}"
	cd "$tb"
	hdlmake
	make clean
	make
	cd ../../..
done
