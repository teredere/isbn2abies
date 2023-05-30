BEGIN {   # Convertir procesado en columnas isbn cdu ubicación 
          # a formato original con etiquetas. Mejor pasar antes
          #     sort -k3 -k2
      FS = "\t";
      ae=""; 
      ac=""; 
   } 
/./ { 
      if ($3 != ae  || $2 != ac) print "";
      if ($3 != ae) { print "[ " $3 "]";  }
      if ($2 != ac) { print "[CDU " $2 "]";   }
      print $1;
      ae = $3;
      ac = $2;
   }
