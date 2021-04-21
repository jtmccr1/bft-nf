#!/bin/bash
FILE=!{metadata}
BASENAME=${FILE##/*}
OUT=${BASENAME%.*}.nameMap.txt

awk  'NR>1{printf "%s\t%s\n", $2,$1}' !{metadata} > $OUT
