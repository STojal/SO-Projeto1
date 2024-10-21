#!/bin/bash


# option global variables
CHECK=false
REGEX=""

# warning global variables
ERRORS=0
WARNINGS=0

UPDATES=0

COPIES=0
COPIES_SIZE=0

DELETES=0
DELETES_SIZE=0

Help() {
    echo "Run this script to create a backup for a directory."
    echo "Syntax: ./backup.sh [-c] [-b tfile] [-r regexpr] working_dir backup_dir"
    echo "c     only see the output of the script without actually copying anything"
    echo "b     pass a txt file with the names of the files and directories to not be copied"
    echo "r     only copy the files and directories that match the regex expression"
}

backup_copy() {
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

            # check if regex matches basename
            if [[ -n "$REGEX" && ! "$basename" =~ $REGEX ]]; then
                echo "skipping $path - doesn't match regex"
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
            
            # add information
            if [[ -f $backup_dir/$basename ]]; then
                (( UPDATES++ ))
            else
                (( COPIES++ ))
                (( COPIES_SIZE+=$(stat -c%s "$path")  ))
            fi

            if [[ "$CHECK" == false ]]; then
                cp -a "$path" "$backup_dir"
            fi

        # if path is directory
        elif [[ -d "$path" ]]; then

            # check if directory exists in backup, and make one if not
            if [[ ! -d "$backup_dir/$basename" ]]; then
                echo "mkdir $backup_dir/$basename"
                if [[ "$CHECK" == false ]]; then
                    mkdir "$backup_dir/$basename"
                fi
            fi
            
            backup_copy "$path" "$backup_dir/$basename"
        fi
    done
}

backup_remove(){
    local working_dir=$1
    local backup_dir=$2

    for backup_path in $backup_dir/*; do

        local basename=$(basename "$backup_path")

        # if path is file
        if [[ -f "$backup_path" ]]; then

            # if file still exists in working directory
            if [[ ! -f "$working_dir/$basename" ]]; then
                echo "rm $backup_path"
                (( DELETES++ ))
                (( DELETES_SIZE+=$(stat -c%s "$backup_path")  ))
                if [[ "$CHECK" == false ]]; then
                    rm "$backup_path"
                fi
            fi
        
        # if path is directory
        elif [[ -d "$backup_path" ]]; then
            
            
            # remove all contents of directory that no longer exist in working directory
            backup_remove "$working_dir/$basename" "$backup_path"
            # this makes sure the directory is empty if it needs to be removed

            # check if directory still exists in working directory
            if [[ ! -d "$working_dir/$basename" ]]; then
                echo "rmdir $backup_dir/$basename"

                # remove directory in backup
                if [[ "$CHECK" == false ]]; then
                    rmdir "$backup_dir/$basename"
                fi
            fi
            
        fi


    done

}

# parsing options
while getopts 'cr:h' opt; do
    case $opt in
    c)
        echo "(dry run, no changes)"
        CHECK=true
        ;;
    r)  
        REGEX="$OPTARG"
        local test_str=""
        if [[ "$test_str" =~ $REGEX ]]; then
            echo "valid regex"
        elif [[ $? -eq 2 ]]; then
            echo "Error: invalid regex, proceeding without regex."
            REGEX=""
            (( ERRORS++ ))
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

# Check if backup directory is inside the working directory
if [[ "$backup_dir" == "$working_dir"* ]]; then
    echo "Cannot do backup in the original directory"
    exit 1
fi

# Check if backup exists and create it if it doesn't
if [[ -d "$backup_dir" ]]; then
    echo "Backup directory is valid!"
else
    echo "Creating backup directory..."
    if [[ "$CHECK" == false ]]; then
        backup_dir=../$backup_dir
        mkdir -p "$backup_dir"
    fi
    echo "$backup_dir directory was created successfully!"
fi

backup_copy "$working_dir" "$backup_dir"

backup_remove "$working_dir" "$backup_dir"

echo "Backup finished!"
echo "While backing up $working_dir : $ERRORS errors; $WARNINGS warnings; $UPDATES updated; $COPIES copied (${COPIES_SIZE}B); $DELETES deleted (${DELETES_SIZE}B);"
