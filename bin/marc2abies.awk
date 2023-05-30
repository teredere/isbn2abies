##  Lee un archivo delimitado por tabuladores conteniendo la
##  salida de marc3excel.py pasada por xlsx2tab.py y el archivo
##  del log del proceso de crawl_catalogs.sh que generó los
##  archivos MARC. Genera un archivo para importar en Abies, 
##  obtenienro los CDUs y las ubicaciones del archivo de 
##  log, cruzando por el número de registro [Formato 1].
##
##  Opcionalmente, puede reprocesar un archivo en el formato de
##  salida (y que se supone ha sido retocado manualmente) para
##  repetir las validacione y ajustes y regenerar las signaturas,
##  asegurando que es válido para ABIES. [Formato 2].
##
## TO DO: Añadir Idioma a partir de los tags 040 
##
##  INVOCACION
##  ==========
##  
##  [formato 1]
##
##    awk -f bin/marc2abies.awk (log_file) (entrada) > (salida)
##
##  [formato 2]
##
##    awk -f bin/marc2abies.awk -v repro=1 (entrada)
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
##  FUNCIONAMIENTO NORMAL [formato 1]
##  =================================
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
##  FUNCIONAMIENTO EN REPROCESO [formato 2]
##  =======================================
##
##  El archivo e entrada se supone que tiene las mismas columnas que un
##  archivo de salida en funcionamiento normal. Puede tener exactamente las 
##  mismas o incluir columnas adicionales, pero no puede faltar ninguna de
##  las que constituyen la salida en funcionamiento normal. Las columnas
##  adicionales se copian a la salida en usu mismas posiciones. 
##
##  Se realizan las mismas funciones de purgado de caracteres no esperados,
##  ajustes de la longitud y generación de signaturas que se hacen sobre un
##  archivo de entrada en funcionamiento normal.
##
##  Está pensado para ser utilizado en caso de haber realizado depuración y
##  mejora manual sobre un archivo de salida, antes de cargarlo en abies. 
##
##############################################################################
function printHeader() {
    k = 0;
    for (i in arrayNames) 
    {
        printf("%s", arrayNames[i]);
        k++;
        if (k < NUMERO_CAMPOS_ABIES)
            printf("\t");
    }
    print "";
}
#----------------------------------------------------------------------------
function initValues(force) {

    ## force = 1 cuando cargamos al princpio la table de campo desde stringNames
    ##           para poder validar el primer registro

	if (!force && ES_REPROCESO) {
		for (i in arrayNames) 
        {
			arrayValues[arrayNames[i]] = $i;
		}
	} else {
		for (i in arrayNames) {
			arrayValues[arrayNames[i]] = "";
			
		}
	} 
}

#----------------------------------------------------------------------------
function printRow() {
    k = 0
    for (i in arrayNames) {
        printf("%s", arrayValues[arrayNames[i]]);
        k++;
        if (k < NUMERO_CAMPOS_ABIES)
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
function getValue(destName) {
    ## Actualizar el valor de salida correspondiente a un nombre de campo abies
    return arrayValues[destName];
}

#----------------------------------------------------------------------------
function checkNames() {
	if (!ES_REPROCESO) 
		return 0 ;
	## Devuelve true si error false en caso contrario.
	## Asume que $0 contiene el primer registro de un reproceso., debe ser 
	## invocado para NR == 1
	##
    ## Comprueba, para el caso de reproceso,  que todos los campos de salida 
	## de un proceso normal están en el registro de cabecera de la entrada.
	## Si falta alguno, avisa y devuelve true.
	## 
	## Si hay campos en el registro de entrada que no están en la definición
	## del registro de salida, los añade para su tratamiento (copiar a salida)
	## pero envía un aviso por stderr.
	##
	## Se asume, como nueva lista de campos, las que 
	##
	split($0, hdrarray);
	camposnuevos = 0;
	for (ipos in hdrarray) {
		hdr = hdrarray[ipos];
		hdrNames[nhdr] = ipos;
		if (! ( hdr in arrayValues) ) {
			camposnuevos++;
			print "Aviso: Columna " ipos "(" hdrarray[ipos] ") no definida para Abies. Se deja tal cual" >"/dev/stderr";
		}
	}
	nflderr = 0;
	for (hname in arrayValues) {
		if (! hname in hdarray) {
			nflderr++;
			print "ERROR: Columna " hname " no encontrada en la entrada (" FILENAME "). No se procesa el archivo" >"/dev/stderr";
		}
	}
	if (camposnuevos) {  ## Asumimos la nueva lista de campos
		NUMERO_CAMPOS_ABIES = split($0, arrayNames);
        initValues(0);
	}

	return nflderr;
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
function isbnclean(val, quitarguiones) {
    ## quita morralla de ISBN para utilizar como indice
    val = toupper(val);
    gsub(/[^A-Z0-9\-]/, "", val);
    gensub(/-(.)$/, "\\1?", 1, val);
    gensub(/([0-9])([A-Z])$/, "&?", 1, val);
    gsub(/[A-Z]+$/, "",  val); ## quitar anotaciones como "TELA"
    gsub(/?/, "", val);
    val = substr(val, 1, 20);
    if (quitarguiones) {
        gsub(/-/, "", val);
    }
    return val;
}


##############################################################################

BEGIN   {  
            ##
            ## Delimitadores
            ## ----------------------------------------------------------------------------
            
            FS = "\t";  # Input tab delimited
            OFS = FS;   # Output tab delimited
			
			##
			## Número de archivos procesados, debe ser 2 an proceso normal, 1 en reproceso
			##-----------------------------------------------------------------------------
			
			arhivos_procesados = 0;
			
			##
			## Es reproceso?
			##-----------------------------------------------------------------------------
			
			if (repro || reproceso) ES_REPROCESO = 1; else ES_REPROCESO = 0;
			
			##
            ## Array con todos los nombre de campo de salida
            ## ----------------------------------------------------------------------------
           
            stringNames = "RECNO NUMRO  IdEjemplar    Fecha1Info   Fecha2Info  DepositoLegal  ISBN          CDU ";
            stringNames = stringNames  "Autor         Titulo       Subtitulo   RestoPortada   Edicion       LugarEdicion ";
            stringNames = stringNames  "Editorial     AnoEdicion   Extension   CaracteristicasFisicas       Dimensiones ";
            stringNames = stringNames  "Serie         NumeroSerie  Notas       Procedencia    Ubicacion     ISBNEjemplar ";
            stringNames = stringNames  "NumRegistro   FechaAlta    Importe     Moneda         NotasEjemplar ";
            stringNames = stringNames  "Sig1          Sig2         Sig3        Signatura      REF_FUENTE";
            NUMERO_CAMPOS_ABIES = split(stringNames, arrayNames, /  */);
            initValues(1);
            
			##
            ## Número inicial de IdEjemplar (generado, numérico)
            ## ----------------------------------------------------------------------------
           
            numeroCorrelativo = 1000;
            if(ES_REPROCESO) numeroCorrelativo = 1000000;
            
        }
		
END		{
			##
            ## ERROR si no se procesaron 2 archivos (proceso normal) o sólo 1 ) reproceso
            ## ----------------------------------------------------------------------------

			if (ES_REPROCESO) {
				if (arhivos_procesados < 1) {
					print "ERROR: Entrada vacía (reproceso)" >> "/dev/stderr";
					exit 1;
				}
			} else {
				if (archivos procesados < 2) {
					print "ERROR: Faltan archivos. Debe proporcionar archivo_log y archivo_marc." > "/dev/stderr";
					exit 1;
				}
			}
		}

FNR==NR {   
        ###
        ### Carga del archivo de log
        ### ----------------------------------------------------------------------------

		if (!ES_REPROCESO) {   
			# 
			# contamos archivos para la comprobación
			#
			if (NR == 1) arhivos_procesados++; 
			
			#
			# Si no estamos reprocesando, estmos cargando el log (primer archivo)
			#
			# El número de registro de archivo (FNR) es igual al número de registro total
			# únicamente en el proceso del primer archivo (log). Cargamos en memoria y
			# pasamos al siguiente registro sin más proceso. El primer campo es la clave.
			#
			iclean = isbnclean($7, 1); # 1 => quitar guiones
			log_array[iclean]=$0;
			next; ## No hacemos nada más hasta haber cargado el log
		}
    }

        
FNR==1  { 
        ###
        ### Adaptar los nombre de campo y escribir la línea de cabeceras 
        ### ----------------------------------------------------------------------------
        
        # 
        # contamos archivos para la comprobación
        #
        arhivos_procesados++; 
		   
		# 
		# Si es proceso normal, los valores de entrada son campos MARC21 que se van a
		# mapear a los de salida. 
		#
		# Si es reproceso, los campos de entrada son son los de salida. Por seguridad se
		# verifica que se corresponden (checkNames)
		#
		if (ES_REPROCESO) {   
			if (checkNames()) {
				exit 1;
			}
		} else {
            gsub(" ", "_"); 
            gsub(/\\/, "z");
            gsub(/\$/, "s"); 
            split($0, fields);
            for (f in fields) 
            {
                indexes[fields[f]] = f;
            }
        }
		
        #
        # Cabecera
        #
        
		printHeader();
    }

FNR>1 { ### PROCESAR TODA LA ENTRADA
        ###
        ### Inicializar los campos de la salida (a "" o a datos entrada si reproceso)
        ### -------------------------------------------------------------------------------
			
        initValues(0);

        ###
        ### PROCESO NORMAL: Obtener los datos de la entrada desde las etiquetas MARC21
        ### REPROCESO: Obtener los datos de entrada del registro Abies
        ### -------------------------------------------------------------------------------

        if (ES_REPROCESO) {
            # 
            # MAPEAR LAS COLUMNAS DE ENTRADA
            #
            IdEjemplar             = getValue( "IdEjemplar"              );
            Fecha1Info             = getValue( "Fecha1Info"              );
            ISBN                   = getValue( "ISBN"                    );
            Autor                  = getValue( "Autor"                   );
            Titulo                 = getValue( "Titulo"                  );
            Subtitulo              = getValue( "Subtitulo"               );
            Edicion                = getValue( "Edicion"                 );
            LugarEdicion           = getValue( "LugarEdicion"            );
            Editorial              = getValue( "Editorial"               );
            AnoEdicion             = getValue( "AnoEdicion"              );
            Extension              = getValue( "Extension"               );
            CaracteristicasFisicas = getValue( "CaracteristicasFisicas"  );
            Dimensiones            = getValue( "Dimensiones"             );
            NumeroSerie            = getValue( "NumeroSerie"             );
            Serie                  = getValue( "Serie"                   );
            NumeroSerie            = getValue( "NumeroSerie"             );
            Notas                  = getValue( "Notas"                   );
            CDU                    = getValue( "CDU"                     );
            Ubicacion              = getValue( "Ubicacion"               );
            REF_FUENTE             = getValue( "REF_FUENTE"              );
            NUMRO                  = getValue( "NUMRO"                   );
            Sig1                   = getValue( "Sig1"                    );
            Sig2                   = getValue( "Sig2"                    );
            Sig3                   = getValue( "Sig3"                    );
            Signatura              = getValue( "Signatura"               );
            ## Los siguientes campos no see generan ni se validan en un reproceso
            RestoPortada           = getValue( "RestoPortada"            );
            Procedencia            = getValue( "Procedencia"             );
            ISBNEjemplar           = getValue( "ISBNEjemplar"            );
            NumRegistro            = getValue( "NumRegistro"             );
            FechaAlta              = getValue( "FechaAlta"               );
            Importe                = getValue( "Importe"                 );
            Moneda                 = getValue( "Moneda"                  );
            NotasEjemplar          = getValue( "NotasEjemplar"           );
        } else {
            # 
            # EXTRAER DE LOS CAMPOS MARC21
            #
            
            #- Campos especiales RECNO -----------------------------------------------------
            
            RECNO = FNR;
            setValue( "RECNO", RECNO);
            
            
            #- Generar el identficador único de libro requerido por Abies ------------------
           
            IdEjemplar = numeroCorrelativo;
            numeroCorrelativo++;
            
            
            # VER SI LA ENTRADA PROCEDE DE LA BIBLIOTECA NACIONAL DE FRANCIA (BNF) ========

            # Examimanos el registro de cabecera para poder tratar los casos en los que 
            # el datoproviene de la Bibliotheque Bationale de France (BNF) que codifica 
            # de aquella manera UNIMARC en lugar de USMARC) y requiere unos cuantos ajustes
            
            marca  = substr(getColumn("001"), 1, 5);
            if (marca == "FRBNF") BNFquirk = 1; else BNFquirk = 0;

         #- IdEjemplar --------------------------------------------------------------------
            
            # Generar el identficador único de libro requerido por Abies ------------------
          
            IdEjemplar = numeroCorrelativo;
            numeroCorrelativo++;
            
         #- Fecha1Info --------------------------------------------------------------------

            Fecha1Info = substr(getColumn("008"),8,4);
            
            ## BNF quirk
            if (BNFquirk) Fecha1Info = substr(getColumn("100_zz_sa"),1,4);
            
         #- Fecha2Info --------------------------------------------------------------------

            Fecha2Info = substr(getColumn("008"), 7, 1)=="m"?substr(getColumn("008"),12,4): "";
            
         #- DepositoLegal ----------------------------------------------------------------

            setValue( "DepositoLegal"              , getColumn( "017_zz_sa")  );
            
         #- ISBN --------------------------------------------------------------------------

            ISBN = getColumn( "020_zz_sa");
            
            ## B. N. France quirk
            if (BNFquirk) ISBN = getColumn( "010_zz_sa"); 
                    
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
            if(Titulo == "" && BNFquirk) {   
                Titulo = getColumn("200_11_sa");
            } 
            
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
                Titulo = Subtitulo;
                Subtitulo = "";
            }

         #- Edicion ----------------------------------------------------------------------

            Edicion = getColumn("250_zz_sa");
            sub(/^[^0-9]*/, "", Edicion);
            sub(/[^0-9].*/, "", Edicion);
            
         #- LugarEdicion ------------------------------------------------------------------
            
            LugarEdicion = getColumn( "260_zz_sa");
            
            ## BNF quirk
            if (BNFquirk) LugarEdicion = getColumn( "210_zz_sa");
            
         #- Editorial ---------------------------------------------------------------------

            Editorial= getColumn( "260_zz_sb");
            
            ## BNF quirk
            if (BNFquirk) Editorial = getColumn( "210_zz_sc");

         #- AnoEdicion --------------------------------------------------------------------

            AnoEdicion = getColumn( "260_zz_sc");

            ## BNF quirk
            if (BNFquirk) AnoEdicion = getColumn( "210_zz_sd");

         #- Extension ---------------------------------------------------------------------

            Extension = getColumn( "300_zz_sa");
            
            if (BNFquirk) Extension = getColumn( "215_zz_sa")
              
         #- CaracteristicasFisicas --------------------------------------------------------

            CaracteristicasFisicas = getColumn( "300_zz_sb");
          
         #- Dimensiones -------------------------------------------------------------------

            Dimensiones = getColumn( "300_zz_sc");

            if (BNFquirk) {
                Dimensiones = getColumn( "215_zz_sd");
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
                    }
                }
            }
            
            #- DATOS DEL LOG: NUMRO, CDU, UBICACION, REF_FUENTE ------------------------

            log_entry = "";
            log_found = "N";
            
            cleanisbn = isbnclean(ISBN, 1); # 1 => quitar guiones
            
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

     
            # DATOS NO GENERADOS
            # -------------------------------------------------------------------------------
            #- RestoPortada ------------------------------------------------------------------
            #- Procedencia -------------------------------------------------------------------
            #- ISBNEjemplar ------------------------------------------------------------------
            #- NumRegistro -------------------------------------------------------------------
            #- FechaAlta ---------------------------------------------------------------------
            #- Importe -----------------------------------------------------------------------
            #- Moneda ------------------------------------------------------------------------
            #- NotasEjemplar -----------------------------------------------------------------


        ###
        ### HASTA AQUÍ LA OBTENCIÓN DE DATOS EN EL PROCESO NORMAL
        ### ----------------------------------------------------------------------------
        
        } #<<<<<<<<<<<<<< if (!ES_REPROCESO) <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
            

        ###
        ### Adaptar los datos a los requerimientos de Abies
        ### ----------------------------------------------------------------------------
            
        
        #- ISBN -- algunos vienen chungos
        
        ISBN = isbnclean(ISBN, 0); ## no quitar guiones
        
        #- Autor
        
        Autor = purge(Autor);
        if (!Autor) Autor = "n/d"

        #- Titulo
        
        Titulo= purge(Titulo);
        if(Titulo == "") {
            Titulo = "n/d";
        }
        
        #- Subtitulo (y titulo si procede)
        
       Subtitulo = purge(Subtitulo);
       if(Subtitulo && !Titulo) {
            Titulo = "Subtitulo";
            Subtitulo = "";
       }
         
        #- Edicion

        Edicion= purge(Edicion);

        #- LugarEdicion
        
        LugarEdicion = purge(LugarEdicion);    
        gsub(/\]/, "", LugarEdicion);
        gsub(/\[/, "", LugarEdicion);

        #- Editorial

        Editorial = purge(Editorial);

        #- AnoEdicion

        AnoEdicion = purge(AnoEdicion);
        
        #- Extension
        
        Extension = purge(Extension);
        Extension = substr(Extension, 1, 47);  ## ABIES

        #- CaracteristicasFisicas
        
        CaracteristicasFisicas = purge(CaracteristicasFisicas);
        CaracteristicasFisicas = substr(CaracteristicasFisicas, 1, 48); ## Abies

        #- Dimensiones

        Dimensiones = purge(Dimensiones);

        #- Serie      

        Serie = substr(Serie, 1, 45);                   ## Abies

        #- NumeroSerie      
        
        # NumeroSerie tiene que calcularse antes que Serie
        # Abies no soporta los alfabéticos en este campo. 
        gsub(/^[^0-9]*/, "", NumeroSerie);              ## no-numericos iniciales
        gsub(/[^0-9][^0-9]*[0-9]*/, "", NumeroSerie);   ## solo el primer grupo de numeros
        # Abies odia el numero de serie si la serie esta en blanco
        if ( ! Serie && NumeroSerie) {
                Serie = "(pte)"
        }
    

        #- Notas

        gsub(/^[. ]*/, "", Notas);
        Notas = purge(Notas);
        
        #- IdEjemplar debes estar relleno salvo en caso de un reproceso con error
            
        if (!IdEjemplar)  IdEjemplar = numeroCorrelativo++; ## Inicializado a distinto si reproceso
            
        ###
        ### (Re)calcular la signatura (Sig1, Sig2,  Signatura)
        ### ----------------------------------------------------------------------------
            
          
        #- Sig1  (CDU)
        
            Sig1 = CDU? CDU: "///";

        #- Sig2  (Autor)

            mulstr = "COMPILACIO,COMPILADO,COMPILED,ORGANIZAD,ORGANIZED,PREPARADO,PREPARADA,PREPARED,PUBLICADO,PUBLICADA,MINISTERIO,MINISTRY,ORGANIZA,ORGANITZ,EXPOSICI.ON,PUBLICADA,COLABORACI,INFORMACION,INFORMATION,SERVICIO,SERVICE,INFORMATION,GROUP";
            split(mulstr, mularray, ",");
    
           
            if (Autor == "n/d") {
                Sig2 = Autor;
            } else {
                Sig2 = toupper(Autor);
                gsub(/^[A-Z] /, "", Sig2);
                es_multiple = 0;
                for (m in mularray) {
                    if (Sig2 ~ mularray[m]) {
                        es_multiple = 1;
                    }
                }
                if (es_multiple) {
                    Sig2 = "Varios"
                }
                Sig2 = substr(Sig2, 1, 3);
                Sig2 = Sig2? Sig2: "///";
            }
            
        #- Sig2  (Titulo)

            detstr = "el,la,los,las,un,una,unos,unas,der,eine,das,the,a,le,les,l',il,I,II,III,une,y,o";
            detstr = toupper(detstr);
            split(detstr, detarray, ",");
            
            if (Titulo== "n/d") {
                Sig3 = Titulo;
             } else {
                gsub(/^[^A-Z 0-9]]/, "")
                Sig3 = toupper(Titulo);
                for (p in detarray) {
                    det = "^" detarray[p] " ";
                    if (Sig3 ~ det) {
                        gsub(det, "", Sig3);
                    }
                }
                gsub(/^[^A-Z0-9]/, "", Sig3);  #quitar puntuación al principio
                Sig3 = substr(Sig3, 1, 3);
                Sig3 = Sig3? Sig3: "///";
            }

        #- Signatura  (Titulo)
        
        Signatura = Sig1 " - " Sig2 " - " Sig3;
            
        ###
        ### ACTUALIZAR DATOS SALIDA
        ### ----------------------------------------------------------------------------
          
        setValue( "IdEjemplar"              , IdEjemplar );
        setValue( "Fecha1Info"              , Fecha1Info);
        setValue( "ISBN"                    , ISBN);
        setValue( "Autor"                   , Autor);
        setValue( "Titulo"                  , Titulo);
        setValue( "Subtitulo"               , Subtitulo);
        setValue( "Edicion"                 , Edicion);
        setValue( "LugarEdicion"            , LugarEdicion);
        setValue( "Editorial"               , Editorial);
        setValue( "AnoEdicion"              , AnoEdicion);
        setValue( "Extension"               , Extension);
        setValue( "CaracteristicasFisicas"  , CaracteristicasFisicas);
        setValue( "Dimensiones"             , Dimensiones);
        setValue( "NumeroSerie"             , NumeroSerie);
        setValue( "Serie"                   , Serie);
        setValue( "NumeroSerie"             , NumeroSerie);
        setValue( "Notas"                   , Notas);
        setValue( "CDU"                     , CDU);
        setValue( "Ubicacion"               , Ubicacion);
        setValue( "REF_FUENTE"              , REF_FUENTE);
        setValue( "NUMRO"                   , NUMRO);
        setValue( "Sig1"                    , Sig1);
        setValue( "Sig2"                    , Sig2);
        setValue( "Sig3"                    , Sig3);
        setValue( "Signatura"               , Signatura);
          
        #- DATOS NO PROCESADOS, se pasan tal cual si en reproceso
        #----------------------------------------------------------------------------------
          
          
        #- RestoPortada ------------------------------------------------------------------
        #- Procedencia -------------------------------------------------------------------
        #- ISBNEjemplar ------------------------------------------------------------------
        #- NumRegistro -------------------------------------------------------------------
        #- FechaAlta ---------------------------------------------------------------------
        #- Importe -----------------------------------------------------------------------
        #- Moneda ------------------------------------------------------------------------
        #- NotasEjemplar -----------------------------------------------------------------
            
        setValue( "RestoPortada"             , RestoPortada         );
        setValue( "Procedencia"              , Procedencia          );
        setValue( "ISBNEjemplar"             , ISBNEjemplar         );
        setValue( "NumRegistro"              , NumRegistro          );
        setValue( "FechaAlta"                , FechaAlta            );
        setValue( "Importe"                  , Importe              );
        setValue( "Moneda"                   , Moneda               );
        setValue( "NotasEjemplar"            , NotasEjemplar        );
                                                 

        ###
        ### Escribir registro de salida
        ### ----------------------------------------------------------------------------
           
            
            printRow();
              
        }