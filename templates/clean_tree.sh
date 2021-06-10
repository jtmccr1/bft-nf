#!/bin/bash

sed  's/\[[^]]*\]//g' !{divergence_tree} \
	| sed  's/NODE_[^:]*//g' \
	| gotree reformat newick --format nexus >nocomments_divergence_tree.tree

sed  's/\[[^]]*\]//g' !{time_tree} \
	| sed  's/NODE_[^:]*//g' \
	| gotree reformat newick --format nexus >nocomments_time_tree.tree