#--- script de recuperación para reb (catalogos.mecd.es:220/ABNET_REBECA) ------------------------------
# argumentos: 1) ISBN, 2) Nº secuencial (para nombrar salida)
#
# dirmarc =	archivos_marc21
# ext     =	mrc
# TARGET:reb, catalogos.mecd.es:220/ABNET_REBECA, marc21, iso-8859-1, -, Y
#--------------------------------------------------------------------------------
outfile=archivos_marc21/$1.reb.$2.mrc
rm -f TMPMRC TMPRESULT TMPUNEXPECTED $outfile
yaz-client -m TMPMRC <<xfinx  >TMPRESULT
charset iso-8859-1
open catalogos.mecd.es:220/ABNET_REBECA
f @attr 1=7 $1
format marc21
s 1
exit
xfinx
res=`cat TMPRESULT | grep "hits: 0"`
if [ -z "${res}" ]
then
   yaz-marcdump -i marc -o marc -f iso-8859-1 -t utf8 -l 9=97 TMPMRC  > $outfile
   ret=$?
   if ! test -s $outfile
   then
      echo $0 no se pudo crear $outfile. return code = $ret>> TMPUNEXPECTED
      echo =================================================================== >>TMPUNEXPECTED
      cat TMPRESULT >> TMPUNEXPECTED
      echo =================================================================== >>TMPUNEXPECTED
      rm -f  $outfile
      exit 4
   else
     exit 0
   fi
else
   exit 1
fi
