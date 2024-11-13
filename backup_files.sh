#!/bin/bash

# global option variables
CHECK=false
remove_all=false

Help() {
    echo "Run this script to create a backup for a directory."
    echo "Syntax: ./backup.sh [-c] [-b tfile] [-r regexpr] working_dir backup_dir"
    echo "c     only see the output of the script without actually copying anything"
    
}







backup_copy() {
    # iterates a directory recursively and copies its contents to the backup directory while outputting information about what it's doing

    local working_dir=$1
    local backup_dir=$2

    for path in "$working_dir"/*; do

        # make sure path exists
        if [[ ! -e $path ]]; then
            echo "skipping $working_dir - nothing found"
            return
        fi

        # get basename of path for later
        local basename=$(basename "$path")


        # if path is a file
        if [[ -f "$path" ]]; then

            # check if backup/file is newer that file
            if [[ -f "$backup_dir/$basename" \
            && "$backup_dir/$basename" -nt "$path" ]]; then
                echo "skipping $path - file in backup is newer than the present file"
                continue
            fi

            # check modification date
            if [[ -f "$backup_dir/$basename" \
            && ! "$path" -nt "$backup_dir/$basename" ]]; then
                echo "skipping $path - no new changes"
                continue
            fi

            

            # copy the file
            echo "cp -a $path $backup_dir"

            if [[ "$CHECK" == false ]]; then
                cp -a "$path" "$backup_dir"
            fi
        fi
        
    done
}

backup_remove(){
    # iterates trough the backup directory and removes any files that are no longer in the working directory or that shouldn't be there anymore

    local working_dir=$1
    local backup_dir=$2
    local remove_all=$3

    for backup_path in "$backup_dir"/*; do

        local basename=$(basename "$backup_path")

        # if path is file
        if [[ -f "$backup_path" ]]; then
            # if file still exists in working directory
            if [[ ! -f "$working_dir/$basename" ]] \
            || [[ "$remove_all" == true ]]; then 

                echo "rm $backup_path"

                if [[ "$CHECK" == false ]]; then
                    rm "$backup_path"
                fi
            fi

        

            remove_all=false
            
        fi
    done
}

# parsing options
while getopts 'ch' opt; do
    case $opt in
    c)
        echo "(dry run, no changes)"
        CHECK=true
        ;;
    h)
        Help
        exit 0
        ;;
    :)
        echo "Error: option argument was not provided"
        Help
        exit 1
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

# argument variables
working_dir=$1
backup_dir=$2

# check if working directory exists
if [[ ! -d $working_dir ]]; then
    echo "$working_dir is not a directory"
    exit 1
fi

backup_dir="${backup_dir%/}" # remove the trailing slash from the string


if [[ ! "$backup_dir" =~ ^/ ]]; then
    backup_dir="../$backup_dir"
fi

# convert to absolute paths
working_dir=$(cd "$working_dir" && pwd)
backup_dir=$(cd "$(dirname "$backup_dir")" && pwd)/$(basename "$backup_dir")

# check if backup directory is inside the working directory
if [[ "$backup_dir" == "$working_dir"* ]]; then
    echo "Cannot do backup in the original directory"
    exit 1
fi

# check if backup directory exists, and create it if not
if [[ ! -d "$backup_dir" ]]; then
    echo "Creating backup directory: $backup_dir"
    if [[ "$CHECK" == false ]]; then
        mkdir -p "$backup_dir"
    fi
fi

backup_copy "$working_dir" "$backup_dir"

backup_remove "$working_dir" "$backup_dir" "$remove_all"

echo "Backup finished!"