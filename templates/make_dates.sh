#!/bin/bash
fertree extract taxa -i !{tree} \
	| awk '{n=split($1,a,"\|");printf "%s\t%s\n",$1,a[n]}' > tmp.dates
wc -l tmp.dates | awk '{print $1}'> dates.txt
cat tmp.dates >> dates.txt
