#!/bin/bash
# 
# crawl_catalogs.sh
#
# Busca los ISBN contenidos en el archivo isbn.txt sen un conjunto de 
# catálogos accesibles por protocolo Z39.50. 
#
# Está pensado como parte de un workflow para cargar en Abies (u otros
# programas de gestión) datos de una biblioteca ya existente, a partir
# de los ISBN probablemente escaneados.
#
# Los datos CDU y ubicación (y, en realidad, todos los campos que sigan
# al ISBN son pasados a los archivos de salida para su utilización por
# las herramientas aguas abajo.
#
#
# ENTRADA
# =======
#
# El archivo de entrada se debe encontrar en la el subdirectorio 
# 'archivos_entrada' (ver configuración al principio del código
# más adelante)
#
# Se espera que el archivo de entrada sea la salida del shell script 
# preparar_entrada.sh, con nombre 'isbns-cdu-ubi.txt' y la siguiente 
# estructura delimitada por tabuladores (SIN CABECERAS)
#
#       ISBN        ISBN a buscar. Con o sin formato (guiones)
#       CDU         CDU asignado
#       Ubicación   Ubicación en la biblioteca
#
#
# Por ejemplo (espacios añadidos por claridad):
#
#   9788436829259	    34	    Estantería 5
#   978-84-340-1893-8	34	    Estantería 5
#   9788429017113	    34	    Estantería 5
#   978-84-9903-300-6	34	    Estantería 5
#   9788496998087	    34	    Estantería 5
#   84-454-1505-0	    34	    Estantería 5
#   9788499032535	    34	    Estantería 5
#   978-84-7897-941-7	34	    Estantería 5
#   9788447032303	    34	    Estantería 5
#   84-236-3837-5	    34	    Estantería 5
#   9782878441864	    748.4	Anaquel A
#   84-95146-95-9	    748.4	Anaquel B
#
# Para cada fuentem, primero se buscan los datos para el ISBN con formato
# y, si no se encuentra, se eliminan guiones y otros signos de puntuación
# y se busca este ISBN sin formato, a menos que sea igual al ISBN original. 
#
# La busqueda se hace por orden en los catálogos especificados y se
# detiene en cuanto se encuentra uno de ellos.
#
# SALIDAS
# =======
#
# Los archivos de salida se generan en el subdirectorio 'archivos_procesados'
# y en el subdirectorio 'archivos_marc21'
#
# Se generan las siguientes salidas:
#   
#   - isbn-notfound.txt: Relación de ISBNs no encontrados
#           Con a misma estructura que el archivo de entrada, añadiendo
#           al final los números de registro    
#
#   - isbn-found.txt: Relación de ISBNs encontrados
#           Añade campos al principio del archivo de entrada con la 
#           identificación de la fuente en que fue encontrado (ver archivo
#           de configuración de fuentes, más adelante)
#
#   - isbn-log.txt: Resultado de todas las búsquedas
#           Con los siguientes campos:
#           1) Número de registro en el archivo de entrada
#           2) Un timestamp AAAAMMDD.hhmmss
#           3) Un campo de resultado, con el literal "found" o "NOTFOUND"
#           4) Identificador de la fuente (bne, reb, etc.) o "---" si el
#              resultado es NOTFOUND
#           5) Indicador de intento (1 o 2 si se encontró con el ISBN que)
#              aparece en el archivo de entrada o en el ISBN sin formato
#           6) ISBN sin formato 
#           7 en adelante) campos del archivo e entrada (ISBN original, CDU, Ubicación) 
#   
#   - Ficheros .mrc con la información encontradas
#           Por cada ISBN encontrado, un archivo con sus datos en formato
#           MARC, en el subdirectorio "archivos_marc21, con el nombre:
#
#               <isbn-con-formato>.<id-fuente>.<registro>:<indicador>.mrc
#
#           . <id-fuente> es el identificador del catálogo donde se encontró
#             (campo 4 del log).
#           . <registro> es el número de registro en el archivo de entrada,
#             descontando la cabecera (campo 1 del log)
#           . <indicador> es el indicador de en que intento se encontró (campo 
#             5 del log.
#
#
# CONFIGURACIÓN
# =============
#  
# El archivo 'catalogs.txt' debe estar contenido en el subdirectorio 'conf'
# con la relación de catálogos fuente en orden de búsqueda siguiendo la 
# siguiente estructura con 6 campos, delimitada por tabuladores/whitespace
#
#   IdFuente  url-port-db  format   charset  auth  conv     
# 
#   IdFuente    - Cadena corta de caracteres con la que identificaremos la
#                 fuente en los archivos de salida.
#   url-port-db - Datos de conexión: nombre_servidor:puerto[/database]
#                 [] indica que /database es opcional en algunos servidores
#   format      - Descriptor de formato para Z39.50
#   charset     - Juego de caracteres de recuperación 
#   auth        - String de autenticación (usuario/passwoerd) si la fuente 
#                 lo requiere o un guión en caso contrario.
#   conv        - Indica si hay que realizar conversión iso-8859-1 a utf-8  
#                 de los registros MARC21. Esto es necesari para fuentes  
#                 como REBECA o REBIUN que o no devuelven UTF-8 o lo hacen
#                 sin el indicadore de unicode ('a') en la posición 9. Si se
#                 desea mantener el juego de caracteres origen, poner 'N',
#                 'n' o guión en esta posición (o deharla vacía). Para que
#                 se realice la conversión por 'Y', 'y', 'S' o 's'. Otro valor
#                 se avisa como error y se considera 'N'.
#  
# Las líneas en blanco se ignoran, todo lo que sigue a un caracter '#' se 
# considera espacio en blanco.
#
# Para ejemplos, ver el archivo conf/ejemplo_catalogs.txt
#
# NOTAS
# =====
#
# Se puede convertir un archivo de salida (por ejemplo isbn-notfound.txt)
# en un archivo de entrada haciendo
#
#   cut --complement -f 2,3 <archivo> | awk -f bin/salida2entrada.awk > <archivo_nuevo>
# 
# Ejemplo:
#
#   cut --complement -f 2,3 log/isbn-notfound.txt | awk -f bin/salida2entrada.awk > archivos_entrada/entrada_notfound.txt
#
# Antes de proceder se crea un backup de los ficheros de entrada y salida 
# existentes en ./old/crawl_catalog_data.tar.gz y se borran los de salida
# con el indice de lo almacenado en .old/indice_backup_<AAAMMDD.hhmmss>.txt
#
# Utiliza las utilidades yaz de cliente Z39.50 y gestión de archivos MARC
#
#       yaz-client   -- Cliente Z39.50/SRU
#       yaz-marcdump -- Para convertir la salida de REBECA
#
# Para cada fuente (target) configurada se crea un script en ./tmp que
# recupera los datos de esa fuente dado el ISBN. Ese script se llama
# tmp_get_xxx y se borran y se crean de nuevo con cada ejecución.
#
#############################################################################
# 0. configuración
#
this=$0

script_conf=bin/check_config.sh

dir_entrada=archivos_entrada
dir_salida=archivos_procesados
dir_marc21=archivos_marc21
dir_conf=conf
dir_old=old
dir_tmp=tmp
dir_log=log
dir_bak=bak

# -- Se conmprueba que existen
file_conf=$dir_conf/catalogs.txt
file_in=$dir_entrada/isbn-cdu-ubi.txt

# -- se borran antes de empezar (se archivan en bak junto los archivos MARC21)
file_found=$dir_log/isbn-found.txt
file_notfound=$dir_log/isbn-notfound.txt
file_log=$dir_log/isbn-log.txt
file_unexepected=$dir_log/isbn-unexpected_errors.txt

file_backup=$dir_bak/crawl_catalog_data

pref_tmpsh=tmp_get

script_conf=bin/check_config.sh

ext_marc=mrc

#############################################################################
# INICIALIZACIÓN 
#

# --- 1 --- Comprobar entorno


if test ! -r $script_conf
then
    echo $0:" Error: Archivo verificación " $script_conf " no encontrado." >&2
    echo $0:" Comprobar si directorio actual\"" `pwd` "\"es correcto"  >&2
    return 2
fi
sh $script_conf $file_conf $file_in
if test $? -ne 0
then
    echo $0:" Fallo en la verificación del entorno" >&2
    return 127
fi

# --- 2 --- Backup preventivo y borrado de las salidas

times=`date +%y%m%d-%H%M%S`

back_index=$dir_bak/crawl_catalog_data_index_$times.txt

tar cfv $file_backup.$times.tar $this $file_conf $file_in $file_found $file_notfound $file_log $file_unexepected $dir_marc21/*.$ext_marc $dir_tmp/$pref_tmpsh.* > $back_index 2>&1

gzip $file_backup.$times.tar

rm -f  $file_found $file_notfound $file_log $file_unexepected $dir_marc21/*.$ext_marc $dir_tmp/$pref_tmpsh.*
   
#############################################################################
# VALIDAR ERRORES DE BULTO Y PREPARAR LA LISTA DE TARGETS EN TMPTARGETS 
#

rm -f TMPTARGETS
rm -f TMPERRORS

awk -v TMPTARGETS=TMPTARGETS ' \
BEGIN   { 
            errorcount = 0;
        }
/./     {
            gsub(/ *#.*/, ""); gsub(/[ \t][ \t]*/," \t"); 
            if($0 != "") {
                if ($1 == "" || $2 == "" || $3 == "" || $4 == "" || $5 == "" || $6 == "") {
                    print "Línea " FNR ": Hay un campo requerido en blanco. Utilice un guion";
                    errorcount++;
                }
                if (length($6) > 1 || (! ("YyNnSs-" ~ $6))) {
                    print "Línea " FNR ": El valor de opción de conversión (col 6=\"" $6 "\") debe ser S/N/-";
                    errorcount++;
                }
                if ($5 != "-" && (length($5) < 3 || (! ($5 ~ "/")) && $5 "=")) {
                    print "Línea " FNR ": El valor de opción de autenticación (col 5=\"" $5 "\") debe ser - o usuario/password";
                    errorcount++;
                }
                if (length($2) < 4) {
                    print "Línea " FNR ": El valor servidor (col 2=\"" $2 "\") es muy corto";
                    errorcount++;
                }
                print >> TMPTARGETS;
            }
        }
END     { 
            if (errorcount > 0) {
                print errorcount " errores encontrados";
                exit 3;
            } else {
                exit 0;
            }   
             
        }
' $file_conf > TMPERRORS

if test $? -ne 0
then    
    echo $0 ": Fichero de configuración" $file_conf "tiene errores" >&2
    cat TMPERRORS >&2
    cat TMPERRORS >> $file_unexepected
    exit 3
fi

#############################################################################
# CREAR EL SCRIPT DE RECUPERACIÓN (tmp/tmp_get.xxx.sh) PARA CADA TARGET
#

for itarget in `awk '{ print $1 }' TMPTARGETS ` 
do
    script_name=$dir_tmp/$pref_tmpsh.$itarget.sh
    rm -f $script_name
    egrep "^\s"*$itarget TMPTARGETS | awk -v dirmarc=$dir_marc21 -v ext=$ext_marc '
        {
            dolar1="$1";
            dolar2="$2";
            print "#--- script de recuperación para " $1 " (" $2 ") ------------------------------";
            print "# argumentos: 1) ISBN, 2) Nº secuencial (para nombrar salida)";
            print "#";
            print "# dirmarc =\t" dirmarc;
            print "# ext     =\t" ext;
            x=$0; gsub(/[ \t][ \t]*/, ", ", x);
            print "# TARGET:" x
            print "#--------------------------------------------------------------------------------"
            print "outfile=" dirmarc "/" dolar1 "." $1 "." dolar2 "." ext;
            print "rm -f TMPMRC TMPRESULT TMPUNEXPECTED $outfile";
            print "yaz-client -m TMPMRC <<xfinx  >TMPRESULT";
            print "charset " $4;
            if ($5 != "-") {
                print "authentication " $5;
            }
            print "open " $2;
            print "f @attr 1=7 " dolar1;
            print "format " $3;
            print "s 1";
            print "exit";
            print "xfinx";
            print "res=`cat TMPRESULT | grep \"hits: 0\"`";
            print "if [ -z \"${res}\" ]"
            print "then"
            if ("YySs" ~ $6) {
            print "   yaz-marcdump -i marc -o marc -f " $4 " -t utf8 -l 9=97 TMPMRC  > $outfile";
            print "   ret=$?";
            } else {
                print "   cp TMPMRC $outfile"; 
                print "   ret=$?";
            }
            print "   if ! test -s $outfile";
            print "   then";
            print "      echo $0 no se pudo crear $outfile. return code = $ret>> TMPUNEXPECTED";
            print "      echo =================================================================== >>TMPUNEXPECTED";
            print "      cat TMPRESULT >> TMPUNEXPECTED" 
            print "      echo =================================================================== >>TMPUNEXPECTED";
            print "      rm -f  $outfile";
            print "      exit 4";
            print "   else";
            print "     exit 0";  # archivo credo  con éxito
            print "   fi";
            print "else";  
            print "   exit 1";    # yaz-client no devolvio ningún registro
            print "fi"
        }
' >  $script_name

done

#############################################################################
# FUNCION PARA RECUPERAR LOS DATOS DE UN REGISTRO DE LA ENTRADA
#

procesar_linea () {
    lin="$1"
    recno=$2
    isbn_form=`echo "$lin" | awk '{ print $1; }'`
    isbn_noform=`echo "$isbn_form" | awk '{ gsub(/[^A-Z0-9]/,""); print; }'`
    echo -n $2: $isbn_form " "
    targetno=0
    for it in `awk '{ print $1 }' TMPTARGETS `
    do
        echo -n $it 
        script_name=$dir_tmp/$pref_tmpsh.$it.sh
        found=0
        attempt=1
        whichone="N/A"
        for isbn in $isbn_form $isbn_noform
        do
            ########################################## Invocar script correspondiente
            sh $script_name $isbn $recno:$attempt
            retcode=$?
            if test $retcode -eq 0
            then
                found=1;  
                whichone=$isbn
                break 2
            fi
            if test $retcode -eq 4
            then
                cat TMPUNEXPECTED >> $file_unexepected
                echo -n "<UNEXPECTED ERROR>"
                n_unexpected=`expr $n_unexpected + 1`
                break
            fi
            attempt=`expr $attempt + 1`
            if [ $isbn_form = $isbn_noform ]
            then
                break
            fi
        done
        echo -n ","
    done    
    timestamp=`date +%Y%m%d-%H%M%S`
    if test $found -eq 1
    then
        log_code="found";
        log_attempt=$attempt;
        log_source=$it;
        retcode=0;
        echo "$it""\t""$lin"    >> $file_found
        echo ":$attempt found"
    else
        log_code="NOTFOUND";
        log_attempt="N/A";
        log_source="N/A";
        retcode=2;
        echo "$lin" >> $file_notfound
        echo " *FAIL*"
    fi
    echo $recno"\t"$timestamp"\t"$log_code"\t"$log_source"\t"$log_attempt"\t"$isbn_noform"\t""$lin"  >> $file_log
    return $retcode
}

# 1  Número de registro en el archivo de entrada
# 2  Un timestamp AAAAMMDD.hhmmss
# 3  Un campo de resultado, con el literal "found" o "NOTFOUND"
# 4  Identificador de la fuente (bne, reb, etc.) o "---"
# 5  Indicador de intento (1 o 2 si se encontró con el ISBN que)
# 6) ISBN sin formato 
# en adelante: campos del archivo de entrada 
   

#############################################################################
# PROCESAR TODO EL ARCHIVO DE ENTRADA
#

recno=1
start_time=$(date +%s.%3N)
n_found=0
n_unexpected=0

echo "BEGIN " `date "+%Y/%m/%d %H:%M:%S"`

awk '/./ { print }' $file_in | tr -d "\r" > TMPENTRADA
while read -r linea_isbn
do
    procesar_linea "$linea_isbn" $recno
    if test $? -eq 0
    then
        n_found=`expr $n_found + 1`
    fi
    recno=`expr $recno + 1`
    
done < TMPENTRADA

echo "END " `date "+%Y/%m/%d %H:%M:%S"`

	
# elapsed time with millisecond resolution
# keep three digits after floating point.
end_time=$(date +%s.%3N)
elapsed=$(echo "scale=3; $end_time - $start_time" | bc)
percent=$(echo "scale=3; 100.0 * $n_found / $recno" | bc)
persec=$(echo "scale=3; $recno / $elapsed" | bc)
failed=$(echo "$recno - $n_found" | bc)

echo "Buscadas    "$recno " referencias en "$elapsed" s ("$persec" refs/s)"
echo "Encontradas "$n_found" ("$percent"%), no encontradas "$failed
echo "se han producido "$n_unexpected" errores no esperados en conexión Z39.50"
