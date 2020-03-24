#!/usr/bin/env bash
set -e
set -x

output=$(dartfmt ./ -n)
if [ -z $output ] 
then
    exit 0
else
    exit 1
fi