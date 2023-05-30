#--- script de recuperación para bli (z3950cat.bl.uk:9909/ZBLACU) ------------------------------
# argumentos: 1) ISBN, 2) Nº secuencial (para nombrar salida)
#
# dirmarc =	archivos_marc21
# ext     =	mrc
# TARGET:bli, z3950cat.bl.uk:9909/ZBLACU, marc21, utf8, ESDEAR0505/FKJGP9nq, -
#--------------------------------------------------------------------------------
outfile=archivos_marc21/$1.bli.$2.mrc
rm -f TMPMRC TMPRESULT TMPUNEXPECTED $outfile
yaz-client -m TMPMRC <<xfinx  >TMPRESULT
charset utf8
authentication ESDEAR0505/FKJGP9nq
open z3950cat.bl.uk:9909/ZBLACU
f @attr 1=7 $1
format marc21
s 1
exit
xfinx
res=`cat TMPRESULT | grep "hits: 0"`
if [ -z "${res}" ]
then
   cp TMPMRC $outfile
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
