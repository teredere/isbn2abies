##  Lee un archivo delimitado por tabuladores conteniendo la
##  salida de marc3excel.py pasada por xlsx2tab.py y el archivo
##  del log del proceso de crawl_catalogs.sh que generó los
##  archivos MARC. Genera un archivo para importar en Abies, 
##  obtenienro los CDUs y las ubicaciones del archivo de 
##  log, cruzando por el número de registro.
##
##  INVOCACION
##  ==========
##   
##  awk -f bin/marc2abies.awk (log_file) (entrada) > (salida)
##  
##  
##  ATENCION: - Se asume que se invoca esde el directorio de la solución.
##  
##            - (log file) DEBE ser el log con el que se generó (entrada)
##                  normalmente log/isbn-log.txt. DEBE tener al menos una
##                  línea
##
##            - (entrada) dn el script marc2abies.sh  es 
##                  archivos_procesados/TODOS.txt
##  
##            - (salida) en el script marc2abies.sh es 
##                  archivos_procesados/abies-temp.txt
##
##
##  FUNCIONAMIENTO
##  ==============
##
##  marc2exel genera cabeceras con todas las combinaciones de
##  etiquetas y subetiquetas que aparecen en los registros 
##  MARC21 de entrada. por ejemplo:
##  
##     "040 \\ $b",  "040 \\ $c",  "100 00 $a",  "100 11 $0"
##  
##  Para facilitar la gestión en awk y evitar problemas en 
##  Access, este programa sustituye en los nombre de columna  
##  los espacios por caracteres "_", las barras invertidas por
##  "z" y los signos "$" por "s". Así los nombre de columna
##  anteriores quedarían
##
##     "040_zz_sb",  "040_zz_sc",  "100_00_sa",  "100_11_s0"
##   
##  Estos nommbre se utilizan para acceder a las columnas del
##  archivo de entrada. Los nombre de columna del archivo de
##  salida son los de la tabla "Ejemplares" de la base de 
##  datos "Importar.mdb" de Abies: 
##
##      IdEjemplar, Fecha1Info, DepositoLegal, ISBN, etc.
##
##  Ver apartado 16.2 del manual directorio 'doc' o, por ejemplo, en
##
##  http://llegirib.ieduca.caib.es/images/stories/abies/manualrevisat.pdf
##
##  Los mapeos de campos son muy dependiente de la fuente, en
##  muchos casos se han ajustado por prueba y error. Como 
##  referencia se ha usado.
##
##  https://www.loc.gov/marc/bibliographic/bd01x09x.html
## 
##  El campo "Signatura", contiene los datos del tejuelo. Está formado por
##
##      CDU - Autor - Título
##
##  Se calcula aquí después de recuperar el CDU. Los trozos se cargan en 
##  Sig1, Sig2 y Sig3
##
##  Se añaden tres columnas adicionalmente, además de la propia de Abies:
##
##      - RECNO es el número de registro de entrada a este script. 
##      - NUMRO es el número de registro en el archivo de entrada original
##        Como los campos CDU y  ubicación, sólo está disponible si se  
##        encuentra el ISBN en el log de crawl_catalogs.sh (que no está 
##        garantizado). Corresponde al campo 9 del log.
##      - REF_FUENTE con un código que identifica la fuente de donde se 
##        obtuvieron los datos.
##
##  RECNO y NUMRO son las dos primeras columnas de la salida y REF_FUENTE
##  la última.
 
##
##  Se espera que el log crawl_catalogs.sh tenga estos campos
##
##    1) Número de registro en el archivo de entrada
##    2) Un timestamp AAAAMMDD.hhmmss
##    3) Un campo de resultado, con el literal "found" o "NOTFOUND"
##    4) Identificador de la fuente (bne, reb, etc.) o "º" si el
##       resultado es NOTFOUND
##    5) Indicador de intento (1 o 2 si se encontró con el ISBN que)
##       aparece en el archivo de entrada o en el ISBN sin formato
##    6) ISBN sin formato 
##       -- datos de registro de entrada de crawl_catalogs.sh --
##    7) ISBN del registro de entrada.
##    8) Numero de línea de entrada (salida de preparar_entrada.sh).
##    9) Numero de línea del archivo fuente (entrada de preparar_entrada.sh) 
##   10) CDU
##   11) Ubicación) 
##
##  ATENCION
##  ========
##  
##  El log de ejecución de crawl_catalogs.sh se carga completo en memoria,
##  lo que podría causar problemas para procesos con muchos miles de ISBNs.
##
##  Al usar utilidades de Office, es importante *importar* los datos
##  (pestaña datos, > obtener datos de Texto/CSV) en lugar de 
##  abrir sin más los archivos generados. Esto es necesario para que 
##  mantengan la codificación UTF-8; en caso contrario entienden que se 
##  trata de alguna versión de ASCII extendido (Latin-1). Asimismo, hay 
##  que especificar (opción de transformar datos) que los campos son
##  de texto, en caso contrario Office intenta iterpretar algúnos códigos
##  incluidos ISBN) como números.
##
## https://learn.microsoft.com/en-us/office/troubleshoot/access/error-using-special-characters
##
##
##############################################################################
function printHeader() {
    k = 0;
    for (i in arrayNames) 
    {
        printf("%s", arrayNames[i]);
        k++;
        if (k < numerocampos)
            printf("\t");
    }
    print "";
}
#----------------------------------------------------------------------------
function initValues() {
    for (i in arrayNames) {
        arrayValues[arrayNames[i]] = "";
    }
}

#----------------------------------------------------------------------------
function printRow() {
    k = 0
    for (i in arrayNames) {
        printf("%s", arrayValues[arrayNames[i]]);
        k++;
        if (k < numerocampos)
            printf("\t");
    }
    print ""
}
#----------------------------------------------------------------------------
function getColumn(sourceColumn) {
    ## Obtener valor de columna de entrada con nombre adaptado p. e. "040_zz_sc"
    ix = indexes[sourceColumn];
    if ( ( ix == "") || ( ix <= 0) ) 
    {
        return "";
    }
    return $(ix)
}
#----------------------------------------------------------------------------
function setValue(destName, value) {
    ## Actualizar el valor de salida correspondiente a un nombre de campo abies
    arrayValues[destName] = value;
}

#----------------------------------------------------------------------------
function purge(val) {
    ## Limpia el final de línea
    gsub(/[ ;\.,\[\(]*$/, "", val);
    gsub("[ :,.]*$", "", val);
    gsub("/$","", val);
    return val;
}

#----------------------------------------------------------------------------
function isbnclean(val) {
    ## quita morralla de ISBN
    val = toupper(val);
    gsub(/ .*$/, "", val);
    gsub(/[^A-Z0-9]/, "", val)
    gsub(/\(.*/, "", val);
    return val;
}


##############################################################################

BEGIN   {  
            ## Delimitadores
            ## ----------------------------------------------------------------------------
            
            FS = "\t";  # Input tab delimited
            OFS = FS;   # Output tab delimited
            
            ## Array con todos los nombre de campo de salida
            ## ----------------------------------------------------------------------------
           
            stringNames = "RECNO NUMRO  IdEjemplar    Fecha1Info   Fecha2Info  DepositoLegal  ISBN          CDU ";
            stringNames = stringNames  "Autor         Titulo       Subtitulo   RestoPortada   Edicion       LugarEdicion ";
            stringNames = stringNames  "Editorial     AnoEdicion   Extension   CaracteristicasFisicas       Dimensiones ";
            stringNames = stringNames  "Serie         NumeroSerie  Notas       Procedencia    Ubicacion     ISBNEjemplar ";
            stringNames = stringNames  "NumRegistro   FechaAlta    Importe     Moneda         NotasEjemplar ";
            stringNames = stringNames  "Sig1          Sig2         Sig3        Signatura      REF_FUENTE";
            numerocampos = split(stringNames, arrayNames, /  */);
            initValues();
            
            ## Número inicial de IdEjemplar (generado, numérico)
            ## ----------------------------------------------------------------------------
           
            numeroCorrelativo = 1000;
            
        }



FNR==NR {   
        ## Carga del archivo de log
        ## ----------------------------------------------------------------------------
            # El número de registro de archivo (FNR) es igual al número de registro total
            # únicamente en el proceso del primer archivo (log). Cargamos en memoria y
            # pasamos al siguiente registro sin más proceso. El primer campo es la clave
          
            iclean = isbnclean($7);
            log_array[iclean]=$0;
            next;
        }

        
FNR==1  { 
        ### Adaptar los nombre de campo y escribir la línea de cabeceras 
        ### ----------------------------------------------------------------------------
           
            gsub(" ", "_"); 
            gsub(/\\/, "z");
            gsub(/\$/, "s"); 
            split($0, fields);
            for (f in fields) 
            {
                indexes[fields[f]] = f;
            }
            printHeader();
        }

FNR>1    { 
        ### Inicializar los campos de la salida
        ### -------------------------------------------------------------------------------
           
            initValues();

        ### Campos especiales RECNO y REF_FUENTE
        ### -------------------------------------------------------------------------------
            
            RECNO = FNR;
            setValue( "RECNO", RECNO);
            
            
        ### Generar el identficador único de libro requerido por Abies
        ### -------------------------------------------------------------------------------
           
            IdEjemplar = numeroCorrelativo;
            numeroCorrelativo++;
            
            
        ### VER SI LA ENTRADA PROCEDE DE LA BIBLIOTECA NACIONAL DE FRANCIA (BNF) 
        ### -------------------------------------------------------------------------------

            ## Examimanos el registro de cabecera para poder tratar los casos en los que 
            ## el datoproviene de la Bibliotheque Bationale de France (BNF) que codifica 
            ## de aquella manera y requiere unos cuantos ajustes
            
            marca  = substr(getColumn("001"), 1, 5);
            if (marca == "FRBNF") BNFquirk = 1; else BNFquirk = 0;

            
        
        ### Asignar los valores a los campos de salida
        ### -------------------------------------------------------------------------------
           
               
            
         #- IdEjemplar --------------------------------------------------------------------
            
            setValue( "IdEjemplar"                 , IdEjemplar );
            
         #- Fecha1Info --------------------------------------------------------------------

            Fecha1Info = substr(getColumn("008"),8,4);
            
            ## BNF quirk
            if (BNFquirk) Fecha1Info = substr(getColumn("100_zz_sa"),1,4);
            
            setValue( "Fecha1Info"                 , Fecha1Info);
            
            
         #- Fecha2Info --------------------------------------------------------------------

            setValue( "Fecha2Info"                 , substr(getColumn("008"), 7, 1)=="m"?substr(getColumn("008"),12,4): "");
            
         #- DepositoLegal ----------------------------------------------------------------

            setValue( "DepositoLegal"              , getColumn( "017_zz_sa")  );
            
         #- ISBN --------------------------------------------------------------------------

            isbn = getColumn( "020_zz_sa");
            
            ## B. N. France quirk
            if (BNFquirk) isbn = getColumn( "010_zz_sa"); 
            
            ## algunos vienen chungos
            isbn = toupper(isbn);
            gsub(/^  */, "", isbn);
            gsub(/\./, "-", isbn);
            gsub(/[ ][[^0-9]*/, "", isbn);
            gsub(/\(..*/, "", isbn)
            isbn = toupper(substr(isbn,1,20));
            
            setValue( "ISBN"                       , isbn);
            
            
         #- Autor -------------------------------------------------------------------------

            strtags = "100_11_sa,100_00_sa,100_01_sa,700_11_sa,245_11_sc,245_00_sc";
            split(strtags, tags, ",");
            fin = 0;
            Autor = "";
            for (t in tags) {
                Autor = getColumn(tags[t]);
                # print "GET--->" tags[t] " GOT: " Autor;
                if (Autor) {
                    break;
                }
            }
        
            ## BNF quirk
            if( (! Autor) && BNFquirk) {   
                Autor = getColumn("200_11_sf");
            }
          
            Autor = purge(Autor);
            if (!Autor) Autor = "n/d"
            setValue( "Autor", Autor);
                  
         #- Título ------------------------------------------------------------------------


            split("0,1,2,3,4,5,6,7,8,9", digits, ",");
            fin = 0;
            Titulo = "";
            for (d1 in digits) {
                for (d2 in digits) {
                    x = ("245" "_" digits[d1] digits[d2] "_sa");
                    Titulo = getColumn(x);
                    #print "GET--->" x " GOT: " Titulo;
                    if (Titulo > "") {
                        fin = 1;
                        break;
                    }
                    if (fin==1) break;
                }
                if (fin==1) break;
            }
            
            ## BNF quirk
            if(Titulo == "") {   
                Titulo = getColumn("200_11_sa");
            } 
            
            Titulo= purge(Titulo);
            
            if(Titulo == "") {
                Titulo = "n/d";
            }
            
            setValue( "Titulo", Titulo);
                  
         #- Subtitulo ---------------------------------------------------------------------

            split("0,1,2,3,4,5,6,7,8,9", digits, ",");
            fin = 0;
            Subtitulo = "";
            for (d1 in digits) {
                for (d2 in digits) {
                    x = ("245" "_" digits[d1] digits[d2] "_sb");
                    Subtitulo = getColumn(x);
                    #print "GET--->" x " GOT: " Titulo;
                    if (Subtitulo > "") {
                        fin = 1;
                        break;
                    }
                    if (fin==1) break;
                }
                if (fin==1) break;
            }

            ## Rebiun es un poco chapuza con esto
            
            Subtitulo = purge(Subtitulo);
            
            if ((Titulo == "n/d") && Subtitulo) {
                setValue( "Titulo", Subtitulo);
                Titulo = Subtitulo;
                Subtitulo = "";
            }  else {
                setValue( "Subtitulo", Subtitulo);
            }



         #- Edicion ----------------------------------------------------------------------

            Edicion = getColumn("250_zz_sa");
            sub(/^[^0-9]*/, "", Edicion);
            sub(/[^0-9].*/, "", Edicion);
            
            Edicion= purge(Edicion);
            setValue( "Edicion", Edicion);
            
         #- LugarEdicion ------------------------------------------------------------------
            
            LugarEdicion = getColumn( "260_zz_sa");
            
            ## BNF quirk
            if (BNFquirk) LugarEdicion = getColumn( "210_zz_sa");
            
            LugarEdicion = purge(LugarEdicion);    
            gsub(/\]/, "", LugarEdicion);
            gsub(/\[/, "", LugarEdicion);
            setValue( "LugarEdicion", LugarEdicion);
            
         #- Editorial ---------------------------------------------------------------------

            Editorial= getColumn( "260_zz_sb");
            
            ## BNF quirk
            if (BNFquirk) Editorial = getColumn( "210_zz_sc");

            Editorial = purge(Editorial);
            setValue( "Editorial"                  , Editorial  );
            
         #- AnoEdicion --------------------------------------------------------------------

            AnoEdicion = getColumn( "260_zz_sc");

            ## BNF quirk
            if (BNFquirk) AnoEdicion = getColumn( "210_zz_sd");

            setValue( "AnoEdicion", AnoEdicion);
            
         #- Extension ---------------------------------------------------------------------

            Extension = getColumn( "300_zz_sa");
            
            if (BNFquirk) Extension = getColumn( "215_zz_sa")
            
            Extension = purge(Extension);
            
            ## ABIES
            Extension = substr(Extension, 1, 48);
            
            setValue( "Extension", Extension);
            
         #- CaracteristicasFisicas --------------------------------------------------------


            CaracteristicasFisicas = purge(getColumn( "300_zz_sb"));
            
            ## Ajustar para Abies
            
            CaracteristicasFisicas = substr(CaracteristicasFisicas, 1, 48);

            setValue( "CaracteristicasFisicas", CaracteristicasFisicas);
            
         #- Dimensiones -------------------------------------------------------------------

            Dimensiones = getColumn( "300_zz_sc");

            if (BNFquirk) {
                Dimensiones = getColumn( "215_zz_sd");
            }
            
            Dimensiones = purge(Dimensiones);
            
            setValue( "Dimensiones" , Dimensiones);
            
         #- NumeroSerie --- (tiene que ir antes de Serie, que usa el valor obtenido) ------

            split("0,1", digits, ",");
            fin = 0;
            NumeroSerie = "";
            for (d1 in digits) {
                for (d2 in digits) {
                    x = ("490" "_" digits[d1] digits[d2] "_sv");   #- NumeroSerie
                    NumeroSerie = getColumn(x);
                    #print "GET--->" x " GOT: " NumeroSerie;
                    if (NumeroSerie > "") {
                        fin = 1;
                        break;
                    }
                    if (fin==1) break;
                }
                if (fin==1) break;
            }
            
            
            if (fin == 1) {
                ## Abies no soporta los alfabéticos en este campo. 
                gsub(/^[^0-9]*/, "", NumeroSerie);              ## no-numericos iniciales
                gsub(/[^0-9][^0-9]*[0-9]*/, "", NumeroSerie);   ## solo el primer grupo de numeros
                setValue( "NumeroSerie", NumeroSerie);
            }

            
         #- Serie -------------------------------------------------------------------------

            split("0,1", digits, ",");
            fin = 0;
            Serie = "";
            for (d1 in digits) {
                for (d2 in digits) {
                    x = ("490" "_" digits[d1] digits[d2] "_sa");
                    Serie = getColumn(x);
                    #print "GET--->" x " GOT: " Serie;
                    if (Serie > "") {
                        fin = 1;
                        break;
                    }
                    if (fin==1) break;
                }
                if (fin==1) break;
            }

            if (fin==1) {
                # Ajustar para Abies
                Serie = substr(Serie, 1, 45);
                setValue( "Serie", Serie);
            } else {
                # Abies odia el numero de serie se la serie esta en blanco
                if (NumeroSerie) {
                    setValue(Serie, "(pte)")
                }
            }

         #- NumeroSerie --- (tiene que ir antes de Serie, que usa el valor obtenido) ------

            split("0,1", digits, ",");
            fin = 0;
            NumeroSerie = "";
            for (d1 in digits) {
                for (d2 in digits) {
                    x = ("490" "_" digits[d1] digits[d2] "_sv");   #- NumeroSerie
                    NumeroSerie = getColumn(x);
                    #print "GET--->" x " GOT: " NumeroSerie;
                    if (NumeroSerie > "") {
                        fin = 1;
                        break;
                    }
                    if (fin==1) break;
                }
                if (fin==1) break;
            }
            
            
            if (fin == 1) {
                ## Abies no soporta los alfabéticos en este campo. 
                gsub(/^[^0-9]*/, "", NumeroSerie);              ## no-numericos iniciales
                gsub(/[^0-9][^0-9]*[0-9]*/, "", NumeroSerie);   ## solo el primer grupo de numeros
                setValue( "NumeroSerie", NumeroSerie);
            }


         #- Notas -------------------------------------------------------------------------


            Notas = getColumn( "500_zz_sa");
            N2 = getColumn( "501_zz_sa");
            if (N2 > "") Notas = Notas ". " N2;
            N2 = getColumn( "504_zz_sa");
            if (N2 > "") Notas = Notas ". " N2;
            #
            split("0,1,2,8", digits1, ",");
            split("0,z", digits2, ",");             # 0 or #
            tmpnotas = "";
            for (d1 in digits1) {
                for (d2 in digits2) {
                    x = ("505" "_" digits[d1] digits[d2] "_sa");   #- $tmpnotas
                    tmpnotas = getColumn(x);
                    if (tmpnotas > "") {
                        Notas = Notas "." tmpnotas;
                        #print "GET-------------------------------------------->" x " GOT: " tmpnotas " (" Notas ")";                           
                    }
                }
            }
            
            gsub(/^[. ]*/, "", Notas);
            
            Notas = purge(Notas);
            
            setValue( "Notas"                      , Notas  );
            
        ### DATOS DEL LOG: NUMRO, CDU, UBICACION, REFERENCIA ORIGEN
        ### -------------------------------------------------------------------------------

            log_entry = "";
            log_found = "N";
            
            cleanisbn = isbnclean(isbn);
            
            log_entry = log_array[cleanisbn]; 
            
            if (log_entry) {
                log_found = "S";
                split(log_entry, entry_array);
                split(log_entry, entry_array);
                CDU = entry_array[10];
                Ubicacion = entry_array[11];
                NUMRO = entry_array[9];  ## 9 : Línea del archivo fuente
                NUMRO = NUMRO? NUMRO: "@[" RECNO "]";
                REF_FUENTE = entry_array[4] ":" entry_array[5] ":" NUMRO;
            } else {
                CDU = "";
                Ubicacion = "";
                REF_FUENTE = "notfound::@[" RECNO "]";
                NUMRO = "";                
            }
            
            
        
         #- CDU ---------------------------------------------------------------------------

            setValue( "CDU"                        , CDU);
        
         #- Ubicacion ---------------------------------------------------------------------

            setValue( "Ubicacion"                  , Ubicacion);
            
         #- REF_FUENTE --------------------------------------------------------------------

            setValue( "REF_FUENTE"                 , REF_FUENTE);

         #- NUMRO -------------------------------------------------------------------------

            setValue( "NUMRO", NUMRO);
  
         #- Sig1, Sig2, SIg3, Signatura ---------------------------------------------------
            
            Sig1 = CDU? CDU: "---";

            mulstr = "COMPILACIO,COMPILADO,COMPILED,ORGANIZAD,ORGANIZED,PREPARADO,PREPARADA,PREPARED,PUBLICADO,PUBLICADA,MINISTERIO,MINISTRY,ORGANIZA,ORGANITZ,EXPOSICI.ON,PUBLICADA,COLABORACI,INFORMACION,INFORMATION,SERVICIO,SERVICE,INFORMATION,GROUP";
            split(mulstr, mularray, ",");
    
            detstr = "el,la,los,las,un,una,unos,unas,der,eine,das,the,a,le,les,l'";
            detstr = toupper(detstr);
            split(detstr, detarray, ",");
            
            if (Autor == "n/d") {
                Sig2 = Autor;
            } else {
                Sig2 = toupper(Autor);
                es_multiple = 0;
                for (m in mularray) {
                    if (Sig3 ~ mularray[m]) {
                        es_multiple = 1;
                    }
                }
                if (es_multiple) {
                    Sig2 = "(var)"
                }
                Sig2 = substr(Sig2, 1, 3);
                Sig2 = Sig2? Sig2: "---";
            }
            
            if (Titulo== "n/d") {
                Sig3 = Titulo;
             } else {
                Sig3 = toupper(Titulo);
                for (p in detarray) {
                    det = "^" detarray[p] " ";
                    if (Sig3 ~ det) {
                        gsub(det, "", Sig3);
                    }
                }
                gsub(/^[^A-Z0-9]/, "", Sig3);  #quitar puntuación al principio
                Sig3 = substr(Sig3, 1, 3);
                Sig3 = Sig3? Sig3: "---";
            }

            Signatura = Sig1 " / " Sig2 " / " Sig3;
            
            setValue( "Sig1"                       , Sig1);
            setValue( "Sig2"                       , Sig2);
            setValue( "Sig3"                       , Sig3);
            setValue( "Signatura"                  , Signatura);
          
        ### DATOS NO CUMPLIMENTADOS 
        ### -------------------------------------------------------------------------------
          
          
         #- RestoPortada ------------------------------------------------------------------
         #- Procedencia -------------------------------------------------------------------
         #- ISBNEjemplar ------------------------------------------------------------------
         #- NumRegistro -------------------------------------------------------------------
         #- FechaAlta ---------------------------------------------------------------------
         #- Importe -----------------------------------------------------------------------
         #- Moneda ------------------------------------------------------------------------
         #- NotasEjemplar -----------------------------------------------------------------

            setValue( "RestoPortada"               , getColumn( "??????????")  );
            setValue( "Procedencia"                , getColumn( "??????????")  );
            setValue( "ISBNEjemplar"               , getColumn( "??????????")  );
            setValue( "NumRegistro"                , getColumn( "??????????")  );
            setValue( "FechaAlta"                  , getColumn( "??????????")  );
            setValue( "Importe"                    , getColumn( "??????????")  );
            setValue( "Moneda"                     , getColumn( "??????????")  );
            setValue( "NotasEjemplar"              , getColumn( "??????????")  );
 

        ### Escribir registro de salida
        ### ----------------------------------------------------------------------------
           
            
            printRow();
              
        }