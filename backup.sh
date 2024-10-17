#!/bin/bash

#TODO
# - check if backup directory is not inside working directory

Help(){
    echo "Run this script to create a backup for a directory."
    echo "Syntax: ./backup.sh [-c] [-b tfile] [-r regexpr] working_dir backup_dir"
    echo "c     only see the output of the script without actually copying anything"
    echo "b     pass a txt file with the names of the files and directories to not be copied"
    echo "r     only copy the files and directories that match the regex expression"
}

options=()
check=false

# Parse options
while getopts 'ch' opt; do
    case $opt in
        c)
            check=true  # set check to true when -c is passed
            options+=("-c")
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

if [[ $# -ne 2 ]]; then
    echo "Error: invalid number of arguments"
    Help
    exit 1
fi

# Argument variables
working_dir="$1"
backup_dir="$2"

# Check if working directory exists
if [[ -d $working_dir ]]; then
    echo "$working_dir exists and is a directory!"
else
    echo "$working_dir is not a directory"
    exit 1
fi

backup_dir="${backup_dir%/}" # Remove the trailing slash from the string

# Check if backup directory is not inside the working directory
if [[ "$backup_dir" == "$working_dir"* ]]; then
    echo "Cannot backup in the original directory."
    exit 1
fi

# Check if backup exists and create it if it doesn't
if [[ -d "$backup_dir" ]]; then
    echo "Backup directory is valid!"
else
    echo "Creating backup directory..."
    if [[ "$check" == false ]]; then
        mkdir -p "$backup_dir"
    fi
    echo "$backup_dir directory was created successfully!"
fi

# Loop through files in the source directory
for path in "$working_dir"/*; do
    pathname=$(basename "$path")

    # Check to see if it is a directory
    if [[ -d $path ]]; then
        echo "mkdir -p \"$backup_dir/$pathname\""
        echo "./backup.sh ${options[@]} \"$path\" \"$backup_dir/$pathname\""
        if [[ "$check" == false ]]; then
            mkdir -p "$backup_dir/$pathname"
            # Call the script recursively
            ./backup.sh "${options[@]}" "$path" "$backup_dir/$pathname"
        fi
        continue
    fi

    echo "cp \"$path\" \"$backup_dir\""  # always show the command 
    # If check is false, actually copy the file
    if [[ "$check" == false ]]; then
        cp "$path" "$backup_dir"
    fi
done

for backup_path in "$backup_dir"/*; do
    backup_filename=$(basename "$backup_path") 

    # remove file if it doesn't exist in the working directory
    if [[ ! -e "$pwd/$backup_filename" ]]; then
        echo "rm -r $backup_path"  

        if [[ "$check" == false ]]; then
            rm -r "$backup_path"
        fi
    fi
done