#!/bin/bash

# global option variables
CHECK=false
FILE_NAME=""
REGEX=""
arrayFiles=()
remove_all=false

# warning global variables
ERRORS=0
WARNINGS=0

UPDATES=0

COPIES=0
COPIES_SIZE=0

DELETES=0
DELETES_SIZE=0
local_DELETES_SIZE=0;
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
    local filename=$(basename $path)
    if [[ -n "$arrayFiles" && " ${arrayFiles[@]} " =~ " ${filename} " ]]; then
        return 0 # file is ignorable
    fi
    return 1 # file is not ignorable
}

regex_matches() {
    # checks if a file's name matches the regex passed with the -r option

    local path=$1
    local filename=$(basename $path)
    if [[ -z "$REGEX" || "$filename" =~ $REGEX ]]; then
        return 0  # matches regex
    fi
    return 1 # doesn't match regex
}


backup_copy() {
    # iterates a directory recursively and copies its contents to the backup directory while outputting information about what it's doing

    local working_dir=$1
    local backup_dir=$2
    local local_ERRORS=0;
    local local_WARNINGS=0;
    local local_UPDATES=0;
    local local_COPIES=0;
    local local_COPIES_SIZE=0;
    local local_deleted_size=0;
    local local_DELETES_SIZE=0;


    for path in "$working_dir"/*; do

        # make sure path exists
        if [[ ! -e $path ]]; then
            echo "skipping $working_dir - nothing found"
            return
        fi

        # get basename of path for later
        local basename=$(basename "$path")

        #check if the fileToIgnore is equal path
        if is_ignorable "$basename" ; then
            echo "skipping $path - in the ignore file"
            continue
        fi

        # if path is a file
        if [[ -f "$path" ]]; then


            # check if backup/file is newer that file
            if [[ -f "$backup_dir/$basename" \
            && "$backup_dir/$basename" -nt "$path" ]]; then
                echo "skipping $path - file in backup is newer than the present file"
                (( local_WARNINGS++ ))
                continue
            fi


            # check if regex matches basename
            if ! regex_matches "$basename" ; then
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

            # update summary
            if [[ -f $backup_dir/$basename ]]; then
                (( local_UPDATES++ ))
            else
                (( local_COPIES++ ))
                (( local_COPIES_SIZE+=$(stat -c%s "$path")  ))
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
    # Add the local counts to the global counts
    ((ERRORS += local_ERRORS))
    ((WARNINGS += local_WARNINGS))
    ((UPDATES += local_UPDATES))
    ((COPIES += local_COPIES))
    ((COPIES_SIZE += local_COPIES_SIZE))
    ((DELETES += local_DELETES))
    ((DELETES_SIZE += local_DELETES_SIZE))
    echo "While backuping $working_dir: $local_ERRORS errors; $local_WARNINGS warnings; $local_UPDATES updated; $local_COPIES copied (${local_COPIES_SIZE}B); $local_DELETES deleted (${local_DELETES_SIZE}B)"


}

backup_remove(){
    # iterates trough the backup directory and removes any files that are no longer in the working directory or that shouldn't be there anymore

    local working_dir=$1
    local backup_dir=$2
    local remove_all=$3

    # Local counters for this remove operation
    local local_DELETES=0
    local local_DELETES_SIZE=0

    for backup_path in "$backup_dir"/*; do

        local basename=$(basename $backup_path)

        # if path is file
        if [[ -f "$backup_path" ]]; then

            # if file still exists in working directory
            if [[ ! -f "$working_dir/$basename" ]] \
            || is_ignorable "$basename" \
            || ! regex_matches "$basename" \
            || [[ "$remove_all" == true ]]; then 

                echo "rm $backup_path"
                
                # update summary
                (( DELETES++ ))
                (( DELETES_SIZE+=$(stat -c%s "$backup_path")  ))

                if [[ "$CHECK" == false ]]; then
                    rm "$backup_path"
                fi
            fi


        # if path is directory
        elif [[ -d "$backup_path" ]]; then

            if is_ignorable "$basename" ; then
                remove_all=true
            fi
            
            # remove all contents of directory that no longer exist in working directory
            backup_remove "$working_dir/$basename" "$backup_path" "$remove_all"
            # this makes sure the directory is empty if it needs to be removed

            # check if directory still exists in working directory
            if [[ ! -d "$working_dir/$basename" ]] \
            || is_ignorable "$basename" \
            || [[ "$remove_all" == true ]]; then
                echo "rmdir $backup_dir/$basename"

                # remove directory in backup
                if [[ "$CHECK" == false ]]; then
                    rmdir "$backup_dir/$basename"
                fi
            fi

            remove_all=false
            
        fi
    done
    # Add local delete counters to global counters
    ((DELETES += local_DELETES))
    ((DELETES_SIZE += local_DELETES_SIZE))
}

# parsing options
while getopts 'cr:hb:' opt; do
    case $opt in
    c)
        echo "(dry run, no changes)"
        CHECK=true
        ;;
    r)  
        REGEX="$OPTARG"
        test_str=""
        if [[ "$test_str" =~ $REGEX ]]; then
            echo "valid regex"
        elif [[ $? -eq 2 ]]; then
            echo "Error: invalid regex, proceeding without regex."
            REGEX=""
            (( ERRORS++ ))
        fi
        ;;
    b)
        FILE_NAME=${OPTARG}
        #check if file exists 
        echo "Checking file"
        if [ -f "$FILE_NAME" ]; then 
            echo "File exists"
            echo "Processing option -b file name $FILE_NAME"
            readarray -t arrayFiles < $FILE_NAME
        else 
            echo "Error: file  $file_name doesn't exist - proceeding without ignore file"
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

echo "While backuping $path: $ERRORS errors; $WARNINGS warnings; $UPDATES updated; $COPIES copied (${COPIES_SIZE}B); $DELETES deleted (${DELETES_SIZE}B)"
echo "Backup finished!"
