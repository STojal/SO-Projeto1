#!/bin/bash

#TODO
# - check if backup directory is not inside working directory
# - check modification dates of files

Help(){
    echo "Run this script to create a backup for a directory."
    echo "Syntax: ./backup.sh [-c] [-b tfile] [-r regexpr] working_dir backup_dir"
    echo "c     only see the output of the script without actually copying anything"
    echo "b     pass a txt file with the names of the files and directories to not be copied"
    echo "r     only copy the files and directories that match the regex expression"
}

check=false

# parse options
while getopts 'ch' opt; do
    case $opt in
    c)
        echo "Processing option -c (dry run, no copying)"
        check=true  # set check to true when -c is passed
        ;;
    h)
        Help
        exit 0
        ;;
    ?)
        echo "Error: invalid command option"
        Help
        exit 1
        ;;
    esac
done
shift "$(($OPTIND -1))"

if [[ $# -ne 2 ]];then
    echo "Error: invalid number of arguments"
    Help
    exit 1
fi

# argument variables
pwd=$1
backup_dir=$2

# check if working directory exists
if [[ -d $pwd ]]; then
    echo "$pwd exists and is a directory!"
else
    echo "$pwd is not a directory"
    exit 1
fi

# check if backup exists and create it in case it doesn't
if [[ -d $backup_dir ]]; then
    echo "Backup directory is valid!"
else
    echo "Creating backup directory..."
    mkdir -p "$backup_dir"
    echo "$backup_dir directory was created successfully!"
fi

# loop through files in the source directory
for path in "$pwd"/*; do
    if [[ -f $path ]]; then
        echo "cp $path $backup_dir"  # always show the command

        # if check is false, actually copy the file
        if [[ "$check" == false ]]; then
            cp "$path" "$backup_dir"
        fi
    fi
done

echo "backup finished!"
