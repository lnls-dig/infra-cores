#!/bin/sh

set -euo pipefail

# Run simulation
hdlmake makefile
make
vsim -c -do run.do
