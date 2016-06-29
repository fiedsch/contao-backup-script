#!/usr/bin/env bash
# -*- coding: utf-8 -*-
#
# Backup einer Contao Installation (Dateien und Datenbank)
# Diskussionsgrundlage für den Contao Stammtisch München (14.9.2014)
#

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


# Root Verzeichnis aller Webanwendungen

WEB_ROOT=/var/www


# Name der Contao Installationsverzeichnises. Unterverzeichnis von WEB_ROOT.
# Falls Contao im root-Verzeichnis (WEB_ROOT) installiert wurde:
#CONTAO_DIR=.

CONTAO_DIR=name_of_directory


# Soll das files (oder tl_files) Verzeichnis auch gesichert werden?

BACKUP_CONTAO_FILES=1
#BACKUP_CONTAO_FILES=0


# Sollen die Dateien der Contao Installation gesichert werden?
# (Inhalt von CONTAO_DIR, alles außer files bzw. tl_files).

BACKUP_CONTAO_DIRS=1
#BACKUP_CONTAO_DIRS=0

# OS type (sets how to call date with parameters)
#OS='GNU'
OS='BSD'

# Verzeichnis in dem das Haupt-Skript gespeichert ist.
# Wird u.A. für absolute Pfade in cron jobs benötigt.

SCRIPTDIR=/dir/where/the/main/backup_script/is/located

# - - - - - - - - - -
# Ende Konfiguration
# - - - - - - - - - -

# Das Haupt-Skript aufrufen, das die eigentliche Backup-Logik enthält.

source ${SCRIPTDIR}/contao-backup.sh

# Hier evtl. noch alte Backups löschen. Im Haupt-Skript wird dazu
# z.B. die Variable $LASTWEEK gesetzt und man könnte (wenn das
# Backup per cron täglich läuft) mit folgendem Befehl dafür sorgen,
# daß alte Backups "rollierend" gelöscht werden.
#
# rm -f $TARGET_DIR/*${LASTWEEK}*.gz

## EOF ##