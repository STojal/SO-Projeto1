#!/bin/bash

Help(){
    echo "Run this script to create a backup for a directory."
    echo
    echo "Syntax: ./backup.sh [-c] [-b tfile] [-r regexpr] working_dir backup_dir"
    echo "c     only see the output of the script without actually copying anything"
    echo "b     pass a txt file with the names of the files and directories to not be copied"
    echo "r     only copy the files and directories that match the regex expression"
}

if [[ $# -ne 2 ]];then
    # echo "Insira mais informacao para realizar o script"
    Help
    exit 1
fi

pwd=$1
backup_dir=$2

if [[ -d $1 ]]; then
    echo "$1 exists and is a directory!"
else
    echo "$1 is not a directory"
    exit
fi

if [[ -d $backup_dir ]];then
    echo "Backup directory is valid!"
else
    echo "Creating backup directory..."
    backup_dir=~/$backup_dir
    mkdir $backup_dir
    echo "$backup_dir directory was created succesfully!"
fi

for path in $pwd/*; do
    if [[ -f $path ]]; then
        $(cp $pwd/$path $backup_dir)
    fi
done

