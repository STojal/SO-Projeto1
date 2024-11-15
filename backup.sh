#!/bin/bash

# global option variables
CHECK=false
FILE_NAME=""
REGEX=""
arrayFiles=()
remove_all=false

Help() {
    echo "Run this script to create a backup for a directory."
    echo "Syntax: ./backup.sh [-c] [-b tfile] [-r regexpr] working_dir backup_dir"
    echo "c     only see the output of the script without actually copying anything"
    echo "b     pass a txt file with the names of the files and directories to not be copied"
    echo "r     only copy the files and directories that match the regex expression"
}

is_ignorable() {
    # checks if a file can be ignored based on the information in the file passed with the -b option

    local path=$1
    local filename=$(basename "$path")
    if [[ -n "$arrayFiles" && " ${arrayFiles[@]} " =~ " ${filename} " ]]; then
        return 0 # file is ignorable
    fi
    return 1 # file is not ignorable
}

regex_matches() {
    # checks if a file's name matches the regex passed with the -r option

    local path=$1
    local filename=$(basename "$path")
    if [[ -z "$REGEX" || "$filename" =~ $REGEX ]]; then
        return 0  # matches regex
    fi
    return 1 # doesn't match regex
}

backup_sync() {
    # Recursively syncs the working_dir with the backup_dir, displaying a single summary for each directory level

    local working_dir=$1
    local backup_dir=$2
    local remove_all=$3

    # Ensure backup directory exists
    if [[ ! -d "$backup_dir" ]]; then
        echo "mkdir -p $backup_dir"
        if [[ "$CHECK" == false ]]; then
            mkdir -p "$backup_dir"
        fi
    fi

    # Process each item in the working directory
    for path in "$working_dir"/*; do
        if [[ ! -e "$path" ]]; then
            continue
        fi

        local basename=$(basename "$path")
        
        # Skip if file is ignorable
        if is_ignorable "$basename"; then
            continue
        fi

        # Check if path is a file
        if [[ -f "$path" ]]; then
        
            # If the backup file exists and is newer, count a warning
            if [[ -f "$backup_dir/$basename" && "$backup_dir/$basename" -nt "$path" ]]; then
                echo "WARNING: backup entry $backup_dir/$basename is newer than $path; this should not happen."
                continue
            fi

            # If regex does not match, skip the file
            if ! regex_matches "$basename"; then
                continue
            fi

            # If file has no new changes, skip it
            if [[ -f "$backup_dir/$basename" && ! "$path" -nt "$backup_dir/$basename" ]]; then
                continue
            fi
            
            # copying the file
            echo "cp -a $path $backup_dir"
            if [[ "$CHECK" == false ]]; then
                cp -a "$path" "$backup_dir"
            fi

        elif [[ -d "$path" ]]; then
            # Recursively sync the subdirectory
            backup_sync "$path" "$backup_dir/$basename" "$remove_all"
        fi
    done

    # Process each item in the backup directory for removals
    for backup_path in "$backup_dir"/*; do
        local basename=$(basename "$backup_path")

        if [[ ! -e "$backup_path" ]]; then
            continue
        fi

        # If the item does not exist in working_dir or should be ignored, remove it
        if [[ ! -e "$working_dir/$basename" ]] \
        || is_ignorable "$basename" \
        || ! regex_matches "$basename" \
        || $remove_all; then
            if [[ -f "$backup_path" ]]; then
                echo "rm $backup_path"
                if [[ "$CHECK" == false ]]; then
                    rm "$backup_path"
                fi
            elif [[ -d "$backup_path" ]]; then
                # Recursively process the directory for further cleanup
                backup_sync "$working_dir/$basename" "$backup_path" "$remove_all"

                # Remove the directory if it no longer exists in working_dir
                if [[ ! -d "$working_dir/$basename" || "$remove_all" == true ]]; then
                    echo "rmdir $backup_dir/$basename"
                    if [[ "$CHECK" == false ]]; then
                        rmdir "$backup_dir/$basename"
                    fi
                fi
            fi
        fi
    done

}



# Parsing options
while getopts 'cr:hb:' opt; do
    case $opt in
    c)
        echo "(dry run, no changes)"
        CHECK=true
        ;;
    r)  
        REGEX="$OPTARG"
        if echo "" | grep -E "$REGEX" >/dev/null 2>&1; then
            echo "Error: invalid regex, proceeding without regex."
            REGEX=""
        fi
        ;;

    b)
        FILE_NAME=${OPTARG}
        # Check if file exists 
        echo "Checking file"
        if [ -f "$FILE_NAME" ]; then 
            echo "File exists"
            echo "Processing option -b file name $FILE_NAME"
            readarray -t arrayFiles < "$FILE_NAME"
        else 
            echo "Error: file $FILE_NAME doesn't exist - proceeding without ignore file"
        fi
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
shift "$((OPTIND -1))"


if [[ $# -ne 2 ]]; then
    echo "Error: invalid number of arguments"
    Help
    exit 1
fi

# Argument variables
working_dir=$1
backup_dir=$2

# Check if working directory exists
if [[ ! -d $working_dir ]]; then
    echo "$working_dir is not a directory"
    exit 1
fi

# Remove trailing slash from the directory paths
working_dir="${working_dir%/}"
backup_dir="${backup_dir%/}"

# Get absolute paths for more secure validation
abs_working_dir=$(cd "$working_dir" && pwd)
abs_backup_dir=$(cd "$(dirname "$backup_dir")" && pwd)/$(basename "$backup_dir")

# Ensure backup directory is not within the working directory
if [[ "$abs_backup_dir" == "$abs_working_dir"* ]]; then
    echo "Cannot do backup inside the original directory"
    exit 1
fi

# Create backup directory if it does not exist
if [[ ! -d "$backup_dir" ]]; then
    echo "mkdir -p $backup_dir"
    if [[ "$CHECK" == false ]]; then
        mkdir -p "$backup_dir"
    fi
fi

# Perform the sync
backup_sync "$working_dir" "$backup_dir" "$remove_all"

echo "Backup finished!"
