#!/bin/bash

if [[ $# -ne 2 ]]; then
    echo "please enter 2 arguments: the working directory and the backup directory"
fi


working_dir=$1
backup_dir=$2
differences=0

if ! [[ -d "$working_dir" && -d "$backup_dir" ]]; then
    echo "please enter valid directories"
fi

echo "starting backup check..."

# iterate the files in the backup directory
for file in "$backup_dir"/*; do

    filename=$(basename $file)

    if [[ -f "$file" && -f "$working_dir/$filename" ]]; then
        if [[ "$(md5sum $file | cut -d ' ' -f1 )" != "$(md5sum $working_dir/$filename | cut -d ' ' -f1 )" ]]; then
            echo "$file and $working_dir/$filename differ"
            ((differences++))
        fi
    fi

done

echo "backup check finished!"

if [[ $differences -eq 0 ]]; then
    echo "no differences detected"
else
    echo "differences detected: $differences"
fi

