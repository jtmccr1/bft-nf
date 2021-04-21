#!/bin/bash

sed  's/\[[^]]*\]//g' !{tree} \
	| sed  's/NODE_[^:]*//g' \
	| gotree reformat newick --format nexus >nocomments.tree
#       	| gotree brlen setmin -l !{params.min_time_bl}	>nocomments.tree

