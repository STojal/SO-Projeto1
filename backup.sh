#!/bin/bash

#TODO
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
regex=""
options=()

# parsing options
while getopts 'cr:hb:' opt; do
    case $opt in
    c)
        check=true
        options+=("-c")
        ;;
    r)  
        regex="$OPTARG"
        options+=("-r ${OPTARG}")
        ;;
    b)
         
        options+=("-b ${OPTARG}")
        file_name=${OPTARG}
        #check if file exists 
        echo "Checking file"
        if [ -f "$file_name" ]; then 
            echo "File exists"
            echo "Processing option -b file name $file_name"
            file_use=true
        else 
            echo "File doesnt exist prociding normal"
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

if [[ $# -ne 2 ]];then
    echo "Error: invalid number of arguments"
    Help
    exit 1
fi

# argument variables
working_dir=$1
backup_dir=$2

# check if working directory exists
if [[ -d $working_dir ]]; then
    echo "$working_dir exists and is a directory!"
else
    echo "$working_dir is not a directory"
    exit 1
fi
backup_dir="${backup_dir%/}" # remove the trailing slash from the string

#check to see if the backupt directory isnt inside the pwd directory
checkifparent=$(find "$working_dir" -type d -wholename "$backup_dir")
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

arrayEmpty=true
#check the values in the file 
if [[ "$file_use" == true ]]; then 
    readarray -t arrayFiles < $file_name
fi

 #check if exist files to delet
if (( ${#arrayFiles[@]} )); then
    echo "Array not empty"
    arrayEmpty=false;
fi


# loop through files in the source directory
for path in "$working_dir"/*; do
    
    basename=$(basename $path)
    if [[ -f $path ]]; then

        if [[ "$arrayEmpty" == false ]]; then
            #check if the fileTOremove is eual to the atual path
            for fileRemove in "${arrayFiles[@]}"; do 
                if [[ "$fileRemove" == "$filename" ]]; then
                    echo "O ficheiro $path nao vai ser copiado"
                    continue 2
                fi 
            done 
        fi

        # check modification date
        if [[ -f "$backup_dir/$basename" ]] && ! [[ "$path" -nt "$backup_dir/$basename" ]]; then
            continue
        fi

        echo "cp $path $backup_dir"  # always show the command

        if [[ "$check" == false ]]; then
            cp -a "$path" "$backup_dir"
        fi

    elif [[ -d $path ]]; then

        if [[ "$arrayEmpty" == false ]]; then
            #check if the fileTOremove is eual to the atual path
            for directoryToRemove in "${arrayFiles[@]}"; do 
                if [[ "$directoryToRemove" == "$path" ]]; then
                    echo "O directorio $path nao vai ser copiado"
                    continue 2
                fi 
            done 
        fi

        if [[ -d "$backup_dir/$basename" ]] && ! [[ $path -nt "$backup_dir/$basename" ]]; then
            continue
        fi
        
        if ! [[ -d "$backup_dir/$basename" ]]; then
            echo "mkdir -p $backup_dir/$basename"
            if ! [[ check ]]; then
                mkdir -p "$backup_dir/$basename"
            fi
        fi

        ./Teste.sh "${options[@]}" "$path" "$backup_dir/$basename"
        echo "backup finished for the directorio $path!"

    fi
done

# for backup_path in "$backup_dir"/*; do
#     backup_filename=$(basename "$backup_path") 

#     # remove file if it doesn't exist in the working directory
#     if [[ ! -e "$working_dir/$backup_filename" ]]; then
#         echo "rm $backup_path"  

#         if [[ "$check" == false ]]; then
#             rm "$backup_path"
#         fi
#     fi
# done



echo "backup finished!"