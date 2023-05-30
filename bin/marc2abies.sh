#!/bin/bash
#
# marc2abies.sh
#
# Procesa los archivos en el directorio 'archivos_marc21', creados por
# isbn2marc.sh y realiza los siguientes tratamientos (todos los archivos
# se crean en el directorio archivos_procesados).
#
#   1) Los concatena todos en el archivo TODOS.mrc
#   2) Crea una hoja Excel TODOS.xlsx (utilidad marc2excel_cli.py)
#   3) Convierte esta hoja en un fichero de texto (TODOS.txt) con el script
#      xls2tab.py
#   4) Crea un archivo de texto eb columnas delimitado por tabuladores,
#      con los campos que entiende Abies para importar, con los nombres de
#      los campos en la primera fila (script awk marc2abies.awk)
#
#      este archivo se crea en dos versiones: 
#
#           abies-utf8.txt  Codifcación UTF8
#           abies-temp.txt  Codificación Latin 1 
#
#      Este script awkhace un join del archivo del paso anterior con el archivo
#      de log del ultimo proceso de crawl_catalogs.sh (log/isbn-log.txt) que 
#      tiene las ubicaciones y los CDUs pasadas desde el archivo de entrada
#      para incorporar esos datos. 
#
# Este archivo puede ser luego editado (con excel por ejemplo) e importado
# a Abies como se descibe en el apartado 16.2 del manual.
#  
# INVOCACION
# ==========
# 
# Desde el directorio de la solución 
#
#       sh bin/marc2abies.sh  [-n]
#
# Si se proporciona la opción -n, sólo se ejecuta el paso de mapear los campos
# con awk. Para depuración del proceso.
#
# NOTAS
# ===== 
# - Requiere tener instalado Python3, la utilidad marc2excel y las librerías
#   numpy y openpyxl en versiones concretas:
#
#	sudo apt install pip3
#	sudo pip3 install marc2excel
#
#    (si es necesario, desinstalar la versión >= 1.24.0 de la librería numpy)
#    
#   sudo pip3 uninstall numpy
#   sudo pip3 install numpy==1.23.5
#   sudo pip3 install openpyxl==3.0.7
#
# - Utiliza yaz-marcdump para contar los registrs MARC21 resultantes
#
# - Join: ver
#
#   https://unix.stackexchange.com/questions/666005/join-two-tables-based-on-two-columns-in-common-and-add-na-or-empty-values-if-doe?rq=1
#
#############################################################################
# 0. configuración
#
this=$0

script_conf=bin/check_config.sh

marc_dir=archivos_marc21
output=archivos_procesados
input_dir=archivos_entrada

backup_dir=bak
bindir=bin
logdir=log

isbn_cdu_ubi_file=isbn-cdu-ubi.txt
logfile=isbn-log.txt

backup_file=$backup_dir/marc2abies_data
index_file=${backup_file}_index

merged_name=TODOS
abies_latin1=abies-temp.txt
abies_utf8=abies-utf8.txt

#############################################################################
# INICIALIZACIÓN 
#

check_file() {
    sleep 1
    if ! test -s $1
    then
        echo "Error. El archivo "$1" no se pudo crear o está vacío" >&2
        exit 2
    fi    
}

# --- 1 --- Comprobar entorno


if test ! -r $script_conf
then
    echo $0:" Error: Archivo verificación " $script_conf " no encontrado." >&2
    echo $0:" Comprobar si directorio actual\"" `pwd` "\"es correcto"  >&2
    return 2
fi
sh $script_conf $bindir/xlsx2tab.py $bindir/marc2abies.awk $input_dir/$isbn_cdu_ubi_file $logdir/$logfile
if test $? -ne 0
then
    echo $0:" Fallo en la verificación del entorno" >&2
    return 127
fi

#======================================
# Saltar todo el proceso inicial si -n
if [ "x$1" != "x-n" ]
then #------------------------------------------------------------------------------<><><>


# --- 2 --- Backup preventivo y borrado de las salidas

times=`date +%y%m%d-%H%M%S`

tar cfv $backup_file.$times.tar $this $output/$merged_name.*  $output/$abies_latin1 $output/$abies_utf8 > $index_file.$times 2>&1

gzip $backup_file.$times.tar

rm -f  $output/$merged_name.* $output/$abies_latin1 $output/$abies_utf8

echo ""
echo ""
echo "Procesando en "$output
echo ""
#############################################################################
# FUSIONADO DE ARCHIVAS MARC21 
#
n_archivos=`ls -l $marc_dir/*.mrc | wc -l | cut -f 1 -d " "`
echo " "
echo '=================================================================================='
echo '- 1 - Concatenando '$n_archivos' archivos MARC en '$merged_name.mrc
echo '----------------------------------------------------------------------------------'
cat `ls -rt $marc_dir/*.mrc`  > $output/$merged_name.mrc
check_file $output/$merged_name.mrc
n_registros=`yaz-marcdump -i marc -o line $output/$merged_name.mrc | egrep "^001 " | wc -l | cut -f 1 -d " "`
n_bytes=`ls -l $output/$merged_name.mrc | cut -f 5 -d " "`
if test  $n_registros -ne $n_archivos
then
    echo "Atención: no coincide el número de archivos ("$n_archivos") con el de registros ("$n_registros")" >&2
    exit 3
fi
echo '- 1 - FIN. '$n_registros "registros, " $n_bytes "bytes"

#############################################################################
# EXTRACCIÓN DE DATOS A ARCHIVO EXCEL
#
echo " "
echo '=================================================================================='
echo '- 2 - Creando '$merged_name.xlsx con registros MARC21
echo '----------------------------------------------------------------------------------'
marc2excel_cli.py --utf8 $output/$merged_name.mrc
check_file $output/$merged_name.xlsx
echo '- 3 - FIN.  '`ls -l $output/$merged_name.xlsx | cut -f 5 -d " "` " bytes"

#############################################################################
# CONVERSIÓN DEL EXCEL A UN ARCHIVO DELIMITADO POR TABULADORES
#
echo " "
echo '=================================================================================='
echo '3. Conversión de '$merged_name.xlsx ' a '$merged_name.txt
echo '----------------------------------------------------------------------------------'
python3 $bindir/xlsx2tab.py $output/$merged_name.xlsx $output/$merged_name.txt
check_file $output/$merged_name.txt
n_lineas=`wc -l $output/$merged_name.txt | cut -f 1 -d " "`
n_bytes=`ls -l $output/$merged_name.txt | cut -f 5 -d " "`
n_lineas_sin_cab=`expr $n_lineas - 1` # descontar cabecera
if test $n_registros -ne $n_lineas_sin_cab
then
    echo "Atención: no coincide el número de líneas ("$n_lineas_sin_cab" + 1) con el de registros ("$n_registros")" >&2
    exit 3
fi
echo '- 3 - FIN. '$n_lineas' líneas (incluyendo cabecera), '$n_bytes' bytes'

fi #---------------------------------------------------------------------------<><><>
# FIN de Saltar todo el proceso inicial si -n
#======================================


#############################################################################
# TRANSFORMAR A ARCHIVO DELIMITADO CON NOMBRES DE COLUMNA ABIES PARA IMPORTAR
#
echo " "
echo '=================================================================================='
echo '4. Generar archivos '$abies_latin1' y ' $abies_utf8 ' con datos para ABIES'
echo '----------------------------------------------------------------------------------'
awk -f $bindir/marc2abies.awk $logdir/$logfile $output/$merged_name.txt > $output/$abies_utf8
n_lineas_abies=`wc -l $output/$abies_utf8 | cut -f 1 -d " "`
n_lineas_TODO=`wc -l $output/$merged_name.txt | cut -f 1 -d " "`
n_bytes=`ls -l $output/$merged_name.txt | cut -f 5 -d " "`
check_file $output/$abies_utf8
if test $n_lineas_abies -ne $n_lineas_TODO
then
    echo "Atención: no coincide el número de líneas ("$n_lineas_abies") con el del archivo original ("$n_lineas_TODO")" >&2
    exit 3
fi

iconv -c -f utf-8 -t latin1//TRANSLIT $output/$abies_utf8 > $output/$abies_latin1

check_file $output/$abies_latin1
if test $n_lineas_abies -ne $n_lineas_TODO
then
    echo "Atención: no coincide el número de líneas ("$n_lineas_abies") con el del archivo original ("$n_lineas_TODO")" >&2
    exit 3
fi

echo '- 4 - FIN. '$n_lineas_abies "líneas, " $n_bytes "bytes"
