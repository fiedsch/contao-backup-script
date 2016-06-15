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


# - - - - - - - - - -
# Start Konfiguration
# - - - - - - - - - -

# Zielverzeichnis = wo sollen die erzeugten Backups abgelegt werden.
# Auf einem Produktivsystem ist ein öffentlich zugängliches Verzeichnis keine tolle Idee ... :-o

TARGET_DIR=/some/dir/outside/the/webroot


# Basisname der erzeugten Backupdateien. Wenn leer, dann wird der Name
# des Verzeichnisses verwendet, indem sich die Contao Installation befindet.
# (siehe CONTAO_DIR weiter unten).

#DUMP_NAME=''
DUMP_NAME=meinprojekt


# Stammverzeichnis der Contao Installation

WEB_ROOT=/var/www/something


# Name der Contao Installationsverzeichnises. Unterverzeichnis von WEB_ROOT.
# Falls Contao im web root (WEB_ROOT) installiert wurde:
#CONTAO_DIR=.

CONTAO_DIR=name_of_directory


# Soll das files (oder tl_files) Verzeichnis auch gesichert werden?

BACKUP_CONTAO_FILES=1
#BACKUP_CONTAO_FILES=0


# Sollen die Dateien der Contao Installation gesichert werden?
# (Inhalt von CONTAO_DIR, alles außer files bzw. tl_files).

BACKUP_CONTAO_DIRS=1
#BACKUP_CONTAO_DIRS=0

# - - - - - - - - - -
# Ende Konfiguration
# - - - - - - - - - -

# Zeitstempel:
#
# GNU date
#
YESTERDAY=$(date --date "1 days ago" +"%Y-%m-%d")
LASTWEEK=$(date --date "7 days ago" +"%Y-%m-%d")
#
# BSD Date (OSX, ...)
#
#YESTERDAY=$(date -v -1d +"%Y-%m-%d")
#LASTWEEK=$(date -v -1w +"%Y-%m-%d")

TODAY=$(date +"%Y-%m-%d")

# Existieren die angegebenen Verzeichnisse?

if [ ! -d $WEB_ROOT ]
then
    echo "Fehler: WEB_ROOT $WEB_ROOT existiert nicht!"
    exit
fi

if [ ! -d $WEB_ROOT/$CONTAO_DIR ]
then
    echo "Fehler: CONTAO_DIR $WEB_ROOT/$CONTAO_DIR existiert nicht!"
    exit
fi

# Contao Konfigurationsdatei aus der die Zugangsdaten für die Datenbank gelesen werden.
# TODO: Anpassungen für Contao 4.x

CONFIG=$WEB_ROOT/$CONTAO_DIR/system/config/localconfig.php

if [ ! -f $CONFIG ]
then
    echo "Fehler: Konfigurationsdatei localconfig.php nicht gefunden!"
    exit
fi

# Basisname der zu erstellenden Backupdateien entweder aus gesezter Variable oder
# anhand des Namens des Contao-Verzeichnisses CONTAO_DIR.

if [ $DUMP_NAME != '' ]
then
    DUMP=${TARGET_DIR}/$DUMP_NAME_${TODAY}
else
    if [ $CONTAO_DIR = '.' ]
    then
        DUMP=${TARGET_DIR}/contao_aus_root_dir_${TODAY}
    else
        DUMP=${TARGET_DIR}/${CONTAO_DIR}_${TODAY}
    fi
fi

# Statusmessage

echo "$TODAY: erstelle Backup von $WEB_ROOT/$CONTAO_DIR nach ${DUMP}*"

# - - - - - - - - - -
# (1) Dump der Datenbank
# - - - - - - - - - -

# Contaos localconfig.php mit den Datenbankzugangsdaten auslesen

HOST=$(grep dbHost "$CONFIG"         | grep -v '#' | cut -d '=' -f2 | sed "s/^ *'//" | sed "s/'; *$//" )
DATABASE=$(grep dbDatabase "$CONFIG" | grep -v '#' | cut -d '=' -f2 | sed "s/^ *'//" | sed "s/'; *$//" )
USER=$(grep dbUser "$CONFIG"         | grep -v '#' | cut -d '=' -f2 | sed "s/^ *'//" | sed "s/'; *$//" )
PASS=$(grep dbPass "$CONFIG"         | grep -v '#' | cut -d '=' -f2 | sed "s/^ *'//" | sed "s/'; *$//" )


## visual Debug (korrekte Zugangsdaten ausgelesen?)
## echo "host='$HOST' database='$DATABASE' user='$USER' pass='$PASS'" ; exit

# Optionen für mysqldump:
# (1) --skip-extended-insert vs. --extended-insert
# Lesbarkeit vs. Dateigröße und Performance beim wieder Einlesen
#
# (2) --hex-blob wird benötigt für Contao Daten in BLOBs (z.B. UUIDs)
# Aus dem Manual: "Erstellt den Speicherauszug unter Verwendung der Hexadezimalnotation
# (z. B. wird aus 'abc' 0x616263). Betroffen sind die Datentypen BINARY, VARBINARY, BLOB und BIT."
#
echo "Erstelle Datenbankdump"
mysqldump -u $USER -p$PASS \
    --add-drop-table \
    --skip-extended-insert \
    --default-character-set utf8 \
    --hex-blob \
    -h $HOST \
    $DATABASE \
    > ${DUMP}.sql \
    && gzip --force ${DUMP}.sql && echo "done"

# - - - - - - - - - -
# (2) Sicherung der Projekt-Dateien aus files oder tl_files in Contao 3.x bzw. Contao 2.x
# - - - - - - - - - -
if [ $BACKUP_CONTAO_FILES -gt 0 ]
then
    echo "Sichere Projekt-Dateien"

    FILES_DIR=files

    # Contao 3.x
    if [ -d $WEB_ROOT/$CONTAO_DIR/$FILES_DIR ]
    then
        echo "-> aus Verzeichnis $CONTAO_DIR/$FILES_DIR"
    else
        # Contao 2.x
        FILES_DIR=tl_files
        echo "-> aus Verzeichnis $CONTAO_DIR/$FILES_DIR"
        if [ ! -d $WEB_ROOT/$CONTAO_DIR/$FILES_DIR ]
        then
            echo "Fehler: Weder $CONTAO_DIR/files noch $CONTAO_DIR/tl_files existieren! Verzeichnis umbenannt?"
            exit
        fi
     fi

    echo "erstelle Backup des Contao 'files' Verzeichnisses"
    ( cd $WEB_ROOT && tar -c -z -f ${DUMP}_files.tar.gz $CONTAO_DIR/$FILES_DIR && echo "done" )
fi


# - - - - - - - - - -
# (3) Sicherung der Contao System-Dateien
# - - - - - - - - - -

if [ $BACKUP_CONTAO_DIRS -gt 0 ]
then
  echo "erstelle Backup der Contao System-Dateien"
  ( cd $WEB_ROOT && tar -c -z --exclude="$CONTAO_DIR/$FILES_DIR*" -f ${DUMP}.tar.gz $CONTAO_DIR && echo "done" )
fi

# - - - - - - - - - -
# (4) Ende
# - - - - - - - - - -

echo "Backup erstellt. Bitte abholen ;-)"

ls -lh ${DUMP}*

## EOF ##