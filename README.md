# Contao Backup Skript

Skript zur Sicherung einer Contao-Installation (Datenbank und optional Dateien).


## Konfiguration

Im Skript müssen die die Variablen `TARGET_DIR`, `DUMP_NAME`, `WEB_ROOT`und `CONTAO_DIR` gesetzt werden.
Details dazu im Skript. 

Mit den Variablen `BACKUP_CONTAO_FILES`und `BACKUP_CONTAO_DIRS` kann gesteuert werden, ob das `files` Verzeichnis
(`tl_files` bei Contao 2.x) bzw. die Systemverzeichnisse (Installationsdateien) ebenfalls gesichert werden sollen.


## Lizenz 

https://opensource.org/licenses/MIT
