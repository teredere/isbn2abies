#!/bin/bash
#
# Preparar un archivo con códigos ISBN en el que se han introducido 
# secciones para agrupar los ISBN que corresponden a un CDU dado y
# están en una ubicación dada.
#
# El archivo de salida se denomina isbns-cdu-ubi.txt y es el que 
# espera el script crawl_catalogs.sh que implementa la recuperación
# de los registros de los ISBN.
#
# Está pensado para la catalogación de una biblioteca existente; se
# supone que el usuario ha escaneado o introducido manualmente los 
# códigos ISBN por orden de ubicación y asigna CDUs consistentes a
# a grupos de ejemplares próximos.
#
# Los archivos de entrada y salida de este script se espera que estén
# en el directorio archivos_entrada de la utilidad. El script debe ser
# ejecutado desde el directorio superior. 
#
# INVOCACION
# ==========
#
# Desde el directorio de la utilidad:
#
#       bin/preparar_entrada.sh <nombre_de_archivo_de_entrada>
#
#
# ENTRADA
# =======
#
# El archivo de entrada tiene una línea por ISBN y líneas espciales
# en las que aparece el CDU o la ubicación de los ISBNs que siguen.
# Los espacios en blanco o tabuladores se ignoran al principio de 
# las líneas. Las líneas especiales pueden contener corchetes "[]"
# por claridad. Se identifican por la primera palabra descontanto el
# corchete si lo tienen. Esto es: "   CDU 34" es lo mismo que [CDU 34]
#
# Las líneas con corchetes que no se iterpretan se ignoran. 
#
# Las líneas especiales son de los siguientes tipos:
#
#   CDU <x>         - Asigna x como CDU a los ISBN que siguen
#
#   Estante <y>
#   Estantería <y>   - Asigna "Estante y" o "Estantería y" como ubicación
#                      a los ISBN que siguen
#
#   @<z>             - Asigna <z> como ubicación a los ISBN que siguen
#
# SALIDA
# ======
# 
# Archivo isbns-cdu-ubi.txt con las siguientes columnas separadas por
# tabuladores:
#   
#   1: ISBN
#   2: CDU
#   3: Número de línea del archivo de salida
#   4: Número de línea del archivos de entrada
#   5: Ubicación
#   (resto de columnas de la entrada si las hubiera)
#
#
# EJEMPLO
# =======
#
# Dada la siguiente entrada:
#
#       [Estantería 1]
#       [CDU 739.03]
#       2-85088-227-5   Datos no interesantes
#       88-202-0710-9
#       0-88740-124-4   Otros datos
#       0112904173
#       1851490752
#       88-85282-76-8
#       84-934190-1-X
#       [CDU 739.032]
#       84-369-3604-3
#
#       [Estante 5]
#       [CDU 34]
#       9788436829259
#       9788483567579
#       84-309-4183-5
#       84-369-1201-2
#       84-294-4578-1
#       84-236-3837-5
#       [CDU 748.4]
#       9782878441864
#       84-95146-95-9
#       2-911167-04-X
#       488-15561-1-8
#
#       [@Anaquel 23-A]
#       [CDU 35]
#       978-90-6153-864-6
#       2-8264-0080-0
#       84-8156-113-4
#       978-84-8480-221-1
#       
# Se produce la siguiente salida (con espacios añadidos por claridad):
#
#       2-85088-227-5        1    3     739.03    Estantería 1      Datos no interesantes
#       88-202-0710-9        2    4     739.03    Estantería 1  
#       0-88740-124-4        3    5     739.03    Estantería 1      Otros datos
#       0112904173           4    6     739.03    Estantería 1  
#       1851490752           5    7     739.03    Estantería 1  
#       88-85282-76-8        6    8     739.03    Estantería 1  
#       84-934190-1-X        7    9     739.03    Estantería 1  
#       84-369-3604-3        8    11    739.032   Estantería 1  
#       9788436829259        9    15    34        Estante 5     
#       9788483567579        10   16    34        Estante 5     
#       84-309-4183-5        11   17    34        Estante 5     
#       84-369-1201-2        12   18    34        Estante 5     
#       84-294-4578-1        13   19    34        Estante 5     
#       84-236-3837-5        14   20    34        Estante 5     
#       9782878441864        15   22    748.4     Estante 5     
#       84-95146-95-9        16   23    748.4     Estante 5     
#       2-911167-04-X        17   24    748.4     Estante 5     
#       488-15561-1-8        18   25    748.4     Estante 5     
#       978-90-6153-864-6    29   29    35        Anaquel 23-A  
#       2-8264-0080-0        20   30    35        Anaquel 23-A  
#       84-8156-113-4        21   31    35        Anaquel 23-A  
#       978-84-8480-221-1    22   32    35        Anaquel 23-A  
#
#
#
#############################################################################
# 0. configuración
#
this=$0

dir_entrada=archivos_entrada
dir_salida=archivos_entrada
dir_conf=conf
dir_old=old
dir_tmp=tmp
dir_log=log
dir_bak=bak

# -- Se conmprueba que existen
script_conf=bin/check_config.sh
file_conf=$dir_conf/catalogs.txt
file_in="$dir_entrada/$1"

# -- se borran antes de empezar (se archivan en bak junto los archivos MARC21)
file_out=$dir_salida/isbn-cdu-ubi.txt
file_temp=$dir_salida/TMP_ISBN_CDU_UBI


#############################################################################
# INICIALIZACIÓN 
#

# --- 0 ---Argumentos


if [ "x$1" = "x" ]
then
    echo $0: "Debe proporcionar el archivo de entrada a procesar"
    return
fi

# --- 1 --- Comprobar entorno

if test ! -r $script_conf
then
    echo $0:" Error: Archivo verificación " $script_conf " no encontrado." >&2
    echo $0:" Comprobar si directorio actual\"" `pwd` "\"es correcto"  >&2
    return 2
fi
sh $script_conf $file_conf "$file_in" 
if test $? -ne 0
then
    echo $0:" Fallo en la verificación del entorno" >&2
    return 127
fi
    
# --- 2 --- Backup preventivo y borrado de las salidas

rm -f $file_temp

times=`date +%y%m%d-%H%M%S`

if [ -f $file_out ]
then
    mv $file_out $file_out.$times
    e=$?
    gzip $file_out.$times
    mv $file_out.$times.gz $dir_bak
    e=$e$?
    if test "$e" -ne  "00" 
    then
        echo $0: "No se pudo salvaguardar (e="$e") "$file_out >&2
        return 1
    fi
fi


# --- 3 --- Convertimos a UNIX por si el archivo se creó en 


cp $file_in $file_temp
e=$?

fromdos $file_temp
e=$?

if test "$e" -ne  "00" 
then
    echo $0: "No se pudo convertir (fromdos) "$file_temp". ) " >&2
    return 1
fi


n_lineas_in=`wc -l $file_temp | cut -f 1 -d " "`


cat $file_temp | awk '
BEGIN       { 
                CDU = "-"; ubi = "-"; 
                out_line_number=0;
            }
            {   
                skip = 0;
            }
/^\s*$/     {
                next;      # eat out empty lines
            }            
/[\[\]]/    {
                skip = 1       # no imprimir lineas especiales
                gsub(/].*/, ""); # quitar sobrante en las líneas especiales
            }
toupper($0) ~ /ESTANT/ {
                gsub(/[[\[\]]/, "", $0); 
                ubi = $0; 
                skip = 1;
            }
$1 ~ /^@/   {
                gsub(/[\[\]@]/, "", $1); 
                gsub(/ *$/, "")
                ubi = $0;
                skip = 1;
            }            
            
toupper($0) ~ /CDU/       { 
                gsub(/[\[\]]/, "", $1); 
                gsub(/ *[cC][Dd][Uu] */, "");
                gsub(/ *$/, "")
                skip = 1;
                CDU = $1;
            }
skip==0     {   
                gsub(/^ */, "", $1)
                gsub(/[ \.]/, "-", $1);
                out_line_number++;
                printf("%s\t%d\t%d\t%s\t%s", $1, out_line_number, FNR, CDU, ubi);  # Columnas básicas
                $1 = ""; gsub (/^\s*/, ""); # eliminar primera columna
                if (length($0)) printf("%s","\t");
                print $0;
            }
' > $file_out

n_lineas_out=`wc -l $file_out | cut -f 1 -d " "`

echo "FIN. "$n_lineas_in" líneas leídas, "$n_lineas_out" escritas en la salida"

