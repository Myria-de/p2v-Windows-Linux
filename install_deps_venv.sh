#!/usr/bin/env bash
WORKDIR=`pwd`
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
echo -e "- ${GREEN}Prüfe Voraussetzungen...${NC}"
pkgs='qemu-utils wimtools libparted-dev dosfstools ntfs-3g python3-pip python3-venv'
ToInstall=
# Virtualbox ist installiert?
#if [ -z $(which VBoxManage) ]
#then
#echo -e "${RED}Fehler: Bitte installieren Sie zuerst Virtualbox. Abbruch.${NC}"
#exit 1
#fi

for pkg in $pkgs; do
  status="$(dpkg-query -W --showformat='${db:Status-Status}' "$pkg" 2>&1)"
  if [ ! $? = 0 ] || [ ! "$status" = installed ]; then
    install=true
    ToInstall="$ToInstall $pkg" 
    echo "$pkg nicht gefunden"
    #break
  fi
done

if [ -z "$ToInstall" ]
then
echo -e "- ${GREEN}Alle Basis-Voraussetzungen sind erfüllt.${NC}"
else
echo -e "- ${GREEN}Installiere $ToInstall${NC}"
sudo apt -y install $pkgs
fi

# ms-sys ist installiert?
if [ -z $(which ms-sys) ]
then
echo -e "${RED}Das Tool ms-sys fehlt. Installiere das Paket.${NC}"
#echo -e "${RED}https://ms-sys.sourceforge.net/${NC}"
cd $WORKDIR
wget -O ms-sys_2.8.0-1_amd64.deb "https://www.myria.de/?sdm_process_download=1&download_id=324518"
sudo apt install ./ms-sys_2.8.0-1_amd64.deb
#exit 1
fi

python3 -m venv ~/.p2v
~/.p2v/bin/pip3 install clize construct pyparted
