#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Backup einer Contao Installation (Dateien und Datenbank)
# Diskussionsgrundlage für den Contao Stammtisch München (14.9.2014)
#
# LICENSE:
# - https://opensource.org/licenses/MIT
#
# REQUIRES:
# - mysqldump
#
# VERSION:
# - 2016-06-15: Überarbeitete Version (Github Repository) mit ein paar Optionen
#
# TODOs:
# - Anpassungen für Contao 4.x
#   https://community.contao.org/de/showthread.php?56480-Datensicherung-wie-macht-ihr-das&p=369698#post369698
# - Contao-Version entdecken und automatisch anpassen.

# Dieses Skript nicht direkt aufrufen. Es muss in einem Wrapper eingebunden werden
# in dem die hier verwendeten Variablen gesetzt werden.
if [ -z ${CONTAO_DIR} ]
then
    echo "Dieses Skript darf nicht direkt aufgerufen werden!"
    exit
fi

# Check, ob alle benötigten Programme zur Verfügung stehen
for prog in date mysqldump grep sed tar
do
    if [ -z "$(which $prog)" ]
    then
        echo "'$prog' ist nicht verfügbar. Voraussetzungen für dieses Skript prüfen!"
        exit
    fi
done

# Zeitstempel:
# YESTERDAY und LASTWEEK werden aktuell (hier) nicht verwendet!

# Regeln, wie date mit Parametern aufgerufen wird, da die Parameter für
# Linux und Co. vs. macOS unterschiedlich sind.

if [ "$(uname)" = 'Darwin' ]
then
  # BSD Date (OSX, ...)
  YESTERDAY=$(date -v -1d +"%Y-%m-%d")
  LASTWEEK=$(date -v -1w +"%Y-%m-%d")
elif [ "$(expr substr $(uname -s) 1 5)" = 'Linux' ]
then
  # GNU Date (Linux et al.)
  YESTERDAY=$(date --date "1 days ago" +"%Y-%m-%d")
  LASTWEEK=$(date --date "7 days ago" +"%Y-%m-%d")
else
  echo "Your platform ($(uname -a)) is not yet supported. Consider making a pull request!"
  exit 1
fi

TODAY=$(date +"%Y-%m-%d")

# Existieren die angegebenen Verzeichnisse?

if [ ! -d ${WEB_ROOT} ]
then
    echo "Fehler: WEB_ROOT $WEB_ROOT existiert nicht!"
    exit
fi

if [ ! -d ${WEB_ROOT}/${CONTAO_DIR} ]
then
    echo "Fehler: CONTAO_DIR ${WEB_ROOT}/${CONTAO_DIR} existiert nicht!"
    exit
fi

# Contao Konfigurationsdatei aus der die Zugangsdaten für die Datenbank gelesen werden.
# TODO: Anpassungen für Contao 4.x

CONFIG=${WEB_ROOT}/${CONTAO_DIR}/system/config/localconfig.php

if [ ! -f ${CONFIG} ]
then
    echo "Fehler: Konfigurationsdatei localconfig.php nicht gefunden!"
    exit
fi

# Basisname der zu erstellenden Backupdateien entweder aus gesezter Variable oder
# anhand des Namens des Contao-Verzeichnisses CONTAO_DIR.

if [ "${DUMP_NAME}" != '' ]
then
    DUMP=${TARGET_DIR}/${DUMP_NAME}_${TODAY}
else
    if [ ${CONTAO_DIR} = '.' ]
    then
        DUMP=${TARGET_DIR}/contao_aus_root_dir_${TODAY}
    else
        DUMP=${TARGET_DIR}/${CONTAO_DIR}_${TODAY}
    fi
fi

# Statusmessage

echo "${TODAY}: erstelle Backup von ${WEB_ROOT}/${CONTAO_DIR} nach ${DUMP}*"

# - - - - - - - - - -
# (1) Dump der Datenbank
# - - - - - - - - - -

# Contaos localconfig.php mit den Datenbankzugangsdaten auslesen

HOST=$(grep '^\$GLOBALS' "${CONFIG}"      | grep dbHost       | grep -v '#' | cut -d '=' -f2 | sed "s/^ *'//" | sed "s/'; *$//" )
DATABASE=$(grep '^\$GLOBALS' "${CONFIG}"  | grep dbDatabase  | grep -v '#' | cut -d '=' -f2 | sed "s/^ *'//" | sed "s/'; *$//" )
USER=$(grep '^\$GLOBALS' "${CONFIG}"      | grep dbUser      | grep -v '#' | cut -d '=' -f2 | sed "s/^ *'//" | sed "s/'; *$//" )
PASS=$(grep '^\$GLOBALS' "${CONFIG}"      | grep dbPass      | grep -v '#' | cut -d '=' -f2 | sed "s/^ *'//" | sed "s/'; *$//" )


## visual Debug (korrekte Zugangsdaten ausgelesen?)
## echo -e "host='${HOST}'\ndatabase='${DATABASE}'\nuser='${USER}'\npass='${PASS}'" ; exit

# Optionen für mysqldump:
# (1) --skip-extended-insert vs. --extended-insert
# Lesbarkeit vs. Dateigröße und Performance beim wieder Einlesen
#
# (2) --hex-blob wird benötigt für Contao Daten in BLOBs (z.B. UUIDs)
# Aus dem Manual: "Erstellt den Speicherauszug unter Verwendung der Hexadezimalnotation
# (z. B. wird aus 'abc' 0x616263). Betroffen sind die Datentypen BINARY, VARBINARY, BLOB und BIT."
#
echo "Erstelle Datenbankdump"
mysqldump -u ${USER} -p${PASS} \
    --add-drop-table \
    --skip-extended-insert \
    --default-character-set utf8 \
    --hex-blob \
    -h ${HOST} \
    ${DATABASE} \
    > ${DUMP}.sql \
    && gzip --force ${DUMP}.sql && echo "done"

# - - - - - - - - - -
# (2) Sicherung der Projekt-Dateien aus files oder tl_files in Contao 3.x bzw. Contao 2.x
# - - - - - - - - - -

# (2a) "Projektverzeichnis" (=Contaos files/ bzw. tl_files) bestimmen.
# Wird immer benötigt -- spätestens in Schritt 3.

# Contao 3.x
FILES_DIR=files

if [ -d ${WEB_ROOT}/${CONTAO_DIR}/${FILES_DIR} ]
then
  echo "-> Contao 3.x; Verzeichnis ${CONTAO_DIR}/${FILES_DIR}"
else
  # Contao 2.x
  FILES_DIR=tl_files
  if [ -d ${WEB_ROOT}/${CONTAO_DIR}/${FILES_DIR} ]
  then
    echo "-> Contao 2.x; Verzeichnis ${CONTAO_DIR}/${FILES_DIR}"
  else  
    echo "Fehler: Weder ${CONTAO_DIR}/files noch ${CONTAO_DIR}/tl_files existieren! Verzeichnis umbenannt?"
    exit 1
  fi
fi

# (2b) Projektdateien (Verzeichnis files/ bzw. tl_files/) sichern

if [ ${BACKUP_CONTAO_FILES} -gt 0 ]
then
    echo "->Sichere Projekt-Dateien aus ${FILES_DIR}"
    ( cd ${WEB_ROOT} && tar -c -z -f ${DUMP}_files.tar.gz ${CONTAO_DIR}/${FILES_DIR} && echo "done" )
fi


# - - - - - - - - - -
# (3) Sicherung der Contao System-Dateien
# - - - - - - - - - -

if [ ${BACKUP_CONTAO_DIRS} -gt 0 ]
then
  echo "erstelle Backup der Contao System-Dateien"
  ( cd ${WEB_ROOT} && tar -c -z --exclude="${CONTAO_DIR}/${FILES_DIR}/*" -f ${DUMP}.tar.gz ${CONTAO_DIR} && echo "done" )
fi

# - - - - - - - - - -
# (4) Ende
# - - - - - - - - - -

echo "Backup erstellt. Bitte abholen ;-)"

ls -lh ${DUMP}*

## EOF ##
