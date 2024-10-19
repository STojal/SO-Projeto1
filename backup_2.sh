#!/bin/bash

# Global variables for options
CHECK=false
EXCLUDE_FILE=""
REGEX=""

Help(){
    echo "Run this script to create a backup for a directory."
    echo "Syntax: ./backup.sh [-c] [-b tfile] [-r regexpr] working_dir backup_dir"
    echo "c     only see the output of the script without actually copying anything"
    echo "b     pass a txt file with the names of the files and directories to not be copied"
    echo "r     only copy the files and directories that match the regex expression"
}

backup_directory() {
    local pwd="$1"
    local backup_dir="$2"

    # Use nullglob to handle cases where no files match the glob pattern
    shopt -s nullglob

    # loop through files and directories in the source directory
    for path in "$pwd"/*; do
        # Check if the loop actually found any files
        if [[ ! -e "$path" ]]; then
            echo "No files or directories found in $pwd"
            return
        fi

        local name=$(basename "$path")

        # Check if the file/directory should be excluded
        if [[ -n "$EXCLUDE_FILE" ]] && grep -q "^$name$" "$EXCLUDE_FILE"; then
            echo "Skipping $path (excluded)"
            continue
        fi

        # Check if the file/directory matches the regex (if provided)
        if [[ -n "$REGEX" ]] && ! [[ "$name" =~ $REGEX ]]; then
            echo "Skipping $path (doesn't match regex)"
            continue
        fi

        if [[ -f "$path" ]]; then
            # check modification date for files
            if [[ -e "$backup_dir/$name" && ! "$path" -nt "$backup_dir/$name" ]]; then
                echo "Skipping $path (not modified)"
                continue
            fi
            echo "cp $path $backup_dir/" # always show the command
            # if CHECK is false, actually copy the file
            if [[ "$CHECK" == false ]]; then
                cp -a "$path" "$backup_dir/"
            fi
        elif [[ -d "$path" ]]; then
            if [[ ! -d "$backup_dir/$name" ]]; then
                echo "mkdir -p $backup_dir/$name"
                if [[ "$CHECK" == false ]]; then
                    mkdir -p "$backup_dir/$name"
                fi
            fi
            
            # Recursive call for subdirectories
            backup_directory "$path" "$backup_dir/$name"
            
            # Update the directory's timestamp after processing its contents
            if [[ "$CHECK" == false ]]; then
                touch -r "$path" "$backup_dir/$name"
            fi
        fi
    done

    # Reset nullglob option
    shopt -u nullglob
}

remove_nonexistent() {
    local pwd="$1"
    local backup_dir="$2"

    # Use nullglob to handle cases where no files match the glob pattern
    shopt -s nullglob

    for backup_path in "$backup_dir"/*; do
        # Check if the loop actually found any files
        if [[ ! -e "$backup_path" ]]; then
            echo "No files or directories found in $backup_dir"
            return
        fi

        local backup_name=$(basename "$backup_path")
        if [[ ! -e "$pwd/$backup_name" ]]; then
            if [[ -d "$backup_path" ]]; then
                echo "rm -r $backup_path"
                if [[ "$CHECK" == false ]]; then
                    rm -r "$backup_path"
                fi
            else
                echo "rm $backup_path"
                if [[ "$CHECK" == false ]]; then
                    rm "$backup_path"
                fi
            fi
        fi
    done

    # Reset nullglob option
    shopt -u nullglob
}

# parse options
while getopts 'chb:r:' opt; do
    case $opt in
        c)
            echo "Processing option -c (dry run, no copying)"
            CHECK=true
            ;;
        h)
            Help
            exit 0
            ;;
        b)
            EXCLUDE_FILE="$OPTARG"
            echo "Using exclude file: $EXCLUDE_FILE"
            if [[ ! -f "$EXCLUDE_FILE" ]]; then
                echo "Error: Exclude file does not exist"
                exit 1
            fi
            ;;
        r)
            REGEX="$OPTARG"
            echo "Using regex: $REGEX"
            ;;
        ?)
            echo "Error: invalid command option"
            Help
            exit 1
            ;;
    esac
done

shift $((OPTIND - 1))

if [[ $# -ne 2 ]]; then
    echo "Error: invalid number of arguments"
    Help
    exit 1
fi

# argument variables
pwd="$1"
backup_dir="$2"

# check if working directory exists
if [[ ! -d "$pwd" ]]; then
    echo "$pwd is not a directory"
    exit 1
fi

echo "$pwd exists and is a directory!"

# check to see if the backup directory isn't inside the pwd directory
if [[ "$(realpath "$backup_dir")" == "$(realpath "$pwd")/"* ]]; then
    echo "Can't do backup in the original directory"
    exit 1
fi

# check if backup exists and create it in case it doesn't
if [[ ! -d "$backup_dir" ]]; then
    echo "Creating backup directory..."
    if [[ "$CHECK" == false ]]; then
        mkdir -p "$backup_dir"
    fi
    echo "$backup_dir directory was created successfully!"
else
    echo "Backup directory is valid!"
fi

backup_dir="${backup_dir%/}" # remove the trailing slash from the string

# Start the backup process
backup_directory "$pwd" "$backup_dir"

# Remove files and directories from backup that don't exist in the working directory
remove_nonexistent "$pwd" "$backup_dir"

echo "backup finished!"