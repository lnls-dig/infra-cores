#!/bin/sh

set -euo pipefail

# Run simulation
hdlmake makefile
make
vsim -i -do run.do &
