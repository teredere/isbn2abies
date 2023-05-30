# Verificar el entorno de utilidades ISBN Abies
#
# Primero comprueba que existen los directorios mínimos para ejecutar 
# Después comprueba que existen los archivos que se pasen en los argumentos
#
# Por ejemplo:
#
#   sh bin/check_config.sh archivos_entrada/isbns-cdu-ubi.txt conf/catalogs.txt
#
#

#------------------------------------------------------------------------------
# Existen los directorios

ret=0
for i in  archivos_entrada archivos_entrada archivos_marc21 archivos_procesados bin conf bak log
do
    if ! test -d $i
    then
        echo $0 ": Directorio" $i "no encontrado"  >&2
        ret=2
    fi
done
if test $ret -ne 0
then    
    echo $0 ": Compruebe si el directorio actual \""`pwd`"\" es correcto"  >&2
    return $ret
fi  

#------------------------------------------------------------------------------
# Existen los archivos

for i in $@
do
    if (! test -f $i) || (! test -s $i)
    then
        echo $0 ": Archivo requerido "$i" no encontrado o vacío." >&2
        ret=2
    fi
done
if test $ret -ne 0
then    
    echo $0 ": Compruebe si se han ejecutado pasos anteriores" >&2
    return $ret
fi  

return 0

    

    


if test ! -r $configfile
then
    echo "Error: Archivo de configuración " $configfile " no encontrado." >&2
    echo "Verificar directorio actual " `pwd`  >&2
    return 2
fi





return 0
