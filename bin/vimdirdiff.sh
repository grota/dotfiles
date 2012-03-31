#!/bin/sh
vim -f '+next' '+execute "DirDiff" argv(0) argv(1)' $@
