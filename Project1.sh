#!/bin/bash
if (( $# < 2 ));then
    echo "Insira mais informacao para realizar o script"
    exit 1
fi

if [ -d $1 ]; then
    echo "Directory exist "
else
    echo "O directorio nao existe!"
    exit
fi

if [ -d $2 ];then
    echo "diretorio de backup valido"
else
    echo "A criar directorio de backup "
    mkdir $2
fi

if [ -z "$(ls -A $2)" ];then
    echo "Backup vazio a copiar todos os ficheiros da diretoria pretendida"
    for file in $(find $1 -maxdepth 1 -type f);do
        echo "cp -a $file "
        
    done 
else
    echo "Atualizar backup"
fi

