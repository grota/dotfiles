#!/bin/sh
oldcwd=$(pwd)

cd "$(dirname "$0")"
for submodule in *; do
	if [ -d "$submodule/.git" ]; then
		cd "$submodule"
		echo "--- $submodule:"
		git fetch origin
		cd ..
	fi
done

cd "$oldcwd"
