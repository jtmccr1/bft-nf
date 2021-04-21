#!/bin/bash
sed -e 's/\[[^\]]*]//g' !{tree} >nocomments.nw
