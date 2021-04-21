#!/bin/bash
FILE=!{metadata}
BASENAME=${FILE##/*}
OUT=${BASENAME%.*}.tsv
echo taxa$'\t'location>$OUT
awk -F , 'NR>1{$2=="UK"?location="UK":location="NonUK";printf "%s|%s\t%s\n",$1,$3, location}' !{metadata} >>$OUT
