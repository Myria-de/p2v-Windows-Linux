#!/bin/bash
#########################
### Konfiguration Windows-Bootumgebung reparieren ###
#########################
WORKDIR=`pwd`
# Hier die VHD/VHDX-Datei eintragen
IMAGEFILE=
# z.B.
# /Windows-VM/Windows10.VHD
# Typische Konfiguration
#NBDEFIPART=1
#NBDWINPART=3
NBDEFIPART=
NBDWINPART=

##########################
### Konfiguration Ende ###
##########################
NBDDEV=/dev/nbd0
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

check-state() {
if ! test $? -eq 0
then
	if ! [ -z "$1" ]
	 then
	 echo -e "${RED}Fehler: $1${NC}"
	 fi
	 exit 1
fi
}

check_pre() {

# Prüfe Voraussetzungen
# ms-sys ist installiert?
if [ -z $(which ms-sys) ]
then
 echo -e "${RED}Fehler: Bitte installieren Sie ms-sys.${NC}"
 echo -e "${RED}https://ms-sys.sourceforge.net/${NC}"
exit 1
fi


# p2v_qemu.py vorhanden?
if [ ! -e $WORKDIR/scripts/p2v_windows.py ]
then
echo -e "${RED}Fehler: Bitte kopieren Sie p2v_windows.py in den Ordner scripts. Abbruch.${NC}"
exit 1
fi

# Python-venv bereits vorhanden?
if [ ! -d $HOME/.p2v ]
then
echo -e "${RED}$HOME/.p2v nicht vorhanden. Starten Sie zuerst install_deps_venv.sh.${NC}"
exit 1
fi

$HOME/.p2v/bin/python3 $WORKDIR/check_modules.py
check-state
echo -e "- ${GREEN}Okay. Alle nötigen Tools gefunden.${NC}"
}
#
# Das Hauptprogramm startet hier
#
# Voraussetzungen prüfen
check_pre

MODULE=nbd
if lsmod | grep "$MODULE" &> /dev/null ; then
  echo -e "- ${GREEN}$MODULE ist bereits geladen.${NC}"
else
  echo -e "- ${RED}$MODULE ist nicht geladen.${NC}"
  echo -e "- ${GREEN}Lade $MODULE${NC}"
  sudo modprobe nbd max_part=8
fi

echo -e "- ${GREEN}Device $NBDDEV für $IMAGEFILE erstellen${NC}"
sudo -E qemu-nbd --disconnect $NBDDEV
sudo -E qemu-nbd -c $NBDDEV  $IMAGEFILE

if [ -z $NBDEFIPART ]
then
 sudo parted -l
 echo -e "- ${RED}Ermitteln Sie die Partitionsnummern auf $NBDDEV${NC}"
 echo -e "- ${RED}und tragen Sie sie in dieses Script ein.${NC}"
 sudo -E qemu-nbd --disconnect $NBDDEV
else
echo -e "- ${GREEN}Erstelle Bootumgebung auf $NBDEFIPART${NC}"
 sudo -E $HOME/.p2v/bin/python3 scripts/p2v_windows.py --disk $NBDDEV --imagefile $IMAGEFILE -e $NBDEFIPART -n $NBDWINPART
 sudo sync
 sudo -E qemu-nbd --disconnect $NBDDEV
fi



