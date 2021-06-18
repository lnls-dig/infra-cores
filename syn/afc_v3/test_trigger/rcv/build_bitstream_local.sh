#!/bin/bash

# Exit on error
set -e
# Check for uninitialized variables
set -u

COMMAND="(hdlmake -a makefile; time make; date) 2>&1 | tee make_output"

echo $COMMAND
eval $COMMAND
