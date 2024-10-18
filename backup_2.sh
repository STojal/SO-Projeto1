#!/bin/bash

#TODO
# - check if backup directory is not inside working directory
# - check modification dates of files
# - when a file is erased on the working directory, its also erased in the backup

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

#check to see if the backupt directory isnt inside the pwd directory
checkifparent=$(find "$pwd" -type d -wholename "$backup_dir")
if [[ -n $checkifparent ]]; then
    echo "Cant do backup in the original directory"
    exit 1
else 
    # check if backup exists and create it in case it doesn't
    if [[ -d "$backup_dir" ]]; then
        echo "Backup directory is valid!"
    else
        echo "Creating backup directory..."
        if [[ "$check" == false ]]; then
            mkdir -p "$backup_dir"
        fi
        echo "$backup_dir directory was created successfully!"
    fi
fi
backup_dir="${backup_dir%/}" # remove the trailing slash from the string

# loop through files in the source directory
for path in "$pwd"/*; do
    if [[ -f $path ]]; then

        filename=$(basename $path)

        # check modification date
        if [[ -e "$backup_dir/$path" \
        && ! "$path" -nt "$backup_dir/$filename" ]]; then
            continue
        fi

        echo "cp $path $backup_dir"  # always show the command

        # if check is false, actually copy the file
        if [[ "$check" == false ]]; then
            cp -a "$path" "$backup_dir"
        fi

    fi
done

for backup_path in "$backup_dir"/*; do
    backup_filename=$(basename "$backup_path") 

    # remove file if it doesn't exist in the working directory
    if [[ ! -e "$pwd/$backup_filename" ]]; then
        echo "rm $backup_path"  

        if [[ "$check" == false ]]; then
            rm "$backup_path"
        fi
    fi
done



echo "backup finished!"
