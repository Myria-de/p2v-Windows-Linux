#!/bin/bash
#########################
# Das Script kopiert die Windows-Partition auf 
# eine virtuelle Festplatte für Qemu oder Virtualbox.
# Alternativ kann auch eine WIM-Datei mit einem Windows-Backup
# verwendet werden.
#########################
#########################
### Konfiguration P2V ###
#########################
# Das Verzeichnis, aus dem das Script aufgerufen wurde
# ist das Arbeitsverzeichnis
WORKDIR=`pwd`
NBDDEV=/dev/nbd0

VMDIR=$WORKDIR/VMs #VMs im Arbeitsverzeichnis speichern
# oder auf einem anderen Laufwerk
#VMDIR=/mnt/sdb2/VMs

# Die Windows-Partition
# ermitteln mit sudo parted -l
WINPART=
# z.B.
# /dev/sda3
# oder
# Eine bereits mit
# wimcapture --config=exclude.ini /dev/sdXX
# erfasste WIM-Datei
WIMFILEPATH="/Windows-VM/w100.wim"
# Tragen Sie die Größe der Imagedatei ein.
# Dieses muss etwas größer sein als die ursprüngliche Windows-Partition. 
IMAGESIZE=700G
####################################
### Konfiguration Virtualisierer ###
####################################
#VMTYPE=QEMU
# oder
VMTYPE=VBOX
# Die Bezeichnung der VM
# Wenn Sie das Script mehrfach ausführen, ändern Sie den Namen
VMNAME="Windows10-8"
### Konfiguration Qemu ###
OSVARIANT="win10" # virt-install --osinfo list

### Konfiguration Virtualbox ###
# Typ der VM
# VBoxManage list ostypes liefert eine Liste der Typen
# z.B. "Windows10" (32-Bit) "Windows10_64" "Windows11_64" "Windows7_64" "Windows7" (32 Bit)
OSTYPE=Windows10_64
NICTYPE=nat
# oder
# NICTYPE=bridged
# Dafür Netzwerkadapter konfigurieren
# Bezeichnung des Netzwerkadapters siehe ip a
NICDEVICE="enp0s3"

##########################
### Konfiguration Ende ###
##########################

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

if [ ! -d $VMDIR/$VMNAME ]
then
echo -e "- ${GREEN}Erstelle Verzeichnis $VMDIR/$VMNAME ${NC}"
mkdir -p $VMDIR/$VMNAME
fi
IMAGEPATH=$VMDIR/$VMNAME

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

if [ "$VMTYPE" = "VBOX" ]
then
  # Virtualbox ist installiert?
 if [ -z $(which VBoxManage) ]
 then
  echo -e "${RED}Fehler: Bitte installieren Sie zuerst Virtualbox. Abbruch.${NC}"
  exit 1
 else
 echo -e "${GREEN}Verwende Virtualbox.${NC}"
 fi 
fi

if [ "$VMTYPE" = "QEMU" ]
then
 # qemu-nbd ist installiert?
 if [ -z $(which  qemu-nbd) ]
 then
  echo -e "${RED}Fehler: Bitte installieren Sie das Paket qemu-utils. Abbruch.${NC}"
  exit 1
 else
  echo -e "${GREEN}Verwende Qemu/KVM.${NC}"
 fi
fi

# p2v_windows.py vorhanden?
if [ ! -e $WORKDIR/scripts/p2v_windows.py ]
then
echo -e "${RED}Fehler: Bitte kopieren Sie p2v_windows.py in den Ordner scripts. Abbruch.${NC}"
exit 1
fi


# wimlib installiert?
if [ -z $(which  wimapply ) ]
then
echo -e "${RED}Fehler: Bitte installieren Sie das Paket wimtools. Abbruch.${NC}"
exit 1
fi

# Python-venv bereits vorhanden?
if [ ! -d $HOME/.p2v ]
then
echo -e "${RED}$HOME/.p2v nicht vorhanden. Starten Sie zuerst install_deps_venv.sh.${NC}"
exit 1
fi

# VM bereits vorhanden?
#if [ -d $VMDIR/$VMNAME ]
#then
#echo -e "${RED}Die VM $VMDIR/$VMNAME existiert bereits."
#echo -e "Bitte löschen Sie die VM in Virtualbox"
#echo -e "oder passen Sie die Konfiguration an.${NC}"
#exit 1
#fi

# qcow2-Datei bereits vorhanden?
#if [ -e $IMAGEPATH ]
# then
# echo -e "${RED}Die Datei $IMAGEPATH existiert bereits."
# echo -e "Bitte entfernen Sie die Datei oder geben Sie einen anderen Namen an.${NC}"
# exit 1
#fi

$HOME/.p2v/bin/python3 $WORKDIR/scripts/check_modules.py
check-state
echo -e "- ${GREEN}Okay. Alle nötigen Tools gefunden.${NC}"
}
##########################################
###      Das Script startet hier       ###
##########################################
# Voraussetzungen prüfen
check_pre

if [ "$VMTYPE" = "QEMU" ]
then
IMAGEFILE=$IMAGEPATH/$VMNAME.qcow2
FORMAT=qcow2
echo -e "- ${GREEN}Erstelle qcow2-Image $IMAGEFILE mit der Größe $IMAGESIZE.${NC}"
#sudo -E 
qemu-img create -f qcow2 $IMAGEFILE $IMAGESIZE
fi
if [ "$VMTYPE" = "VBOX" ]
then
IMAGEFILE=$IMAGEPATH/$VMNAME.vdi
FORMAT=vdi
echo -e "- ${GREEN}Erstelle vdi-Image $IMAGEFILE mit der Größe $IMAGESIZE.${NC}"
#sudo -E
qemu-img create -f vdi $IMAGEFILE $IMAGESIZE
fi

if [ -z $WIMFILEPATH ] && [ -z $WINPART ]
  then
  echo "Konfigurieren Sie WIMFILEPATH oder WINPART."
  exit 1 
fi
if [ ! -z $WIMFILEPATH ] && [ ! -z $WINPART ]
then
  echo "Konfigurieren Sie nur eine der Variablen WIMFILEPATH oder WINPART."
  exit 1
fi

MODULE=nbd
if lsmod | grep "$MODULE" &> /dev/null ; then
  echo -e "- ${GREEN}$MODULE ist bereits geladen.${NC}"
else
  echo -e "- ${RED}$MODULE ist nicht geladen.${NC}"
  echo -e "- ${GREEN}Lade $MODULE${NC}"
  sudo modprobe nbd max_part=8
fi


echo -e "- ${GREEN}Device /dev/nbd0 für $IMAGEPATH erstellen${NC}"
sudo -E qemu-nbd --disconnect $NBDDEV
sudo -E qemu-nbd -c $NBDDEV --format=$FORMAT $IMAGEFILE

echo -e "- ${GREEN}Windows in die qcow2-Datei kopieren${NC}"

if [ ! -z $WINPART ]
then
  echo -e "- ${GREEN}Kopiere $WINPART${NC}"
  sudo -E $HOME/.p2v/bin/python3 scripts/p2v_windows.py --disk=$NBDDEV --winpart=$WINPART
fi

if [ ! -z $WIMFILEPATH ]
then
  echo -e "- ${GREEN}Kopiere $WIMFILEPATH${NC}"
  sudo -E $HOME/.p2v/bin/python3 scripts/p2v_windows.py --disk=$NBDDEV --wimfile=$WIMFILEPATH
fi

sudo -E qemu-nbd --disconnect $NBDDEV

if [ "$VMTYPE" = "QEMU" ]
then
echo -e "- ${GREEN}Erstelle Qemu-VM $VMNAME${NC}"
virt-install --virt-type kvm --name $VMNAME \
    --vcpus 2 \
    --memory 4096 \
    --os-variant $OSVARIANT \
    --disk $IMAGEFILE \
    --cdrom $WORKDIR/drivers/virtio-win-0.1.285.iso \
    --import \
    --network default \
    --boot uefi \
    --graphics spice \
    --noautoconsole \
    --console pty,target_type=serial
virt-manager --connect qemu:///system --show-domain-console $VMNAME    
fi

if [ "$VMTYPE" = "VBOX" ]
then
VBOXPATH=$(which VBoxManage)
echo "Erstelle Virtualbox-VM $VMNAME"
echo -e "- ${GREEN}Virtuelle Maschine mit virtueller Standard-Hardware erstellen.${NC}"

$VBOXPATH createvm --name "$VMNAME" --ostype "$OSTYPE" --register --basefolder "$VMDIR" --default
check-state "VBoxManage createvm: Fehler $?"

echo -e "- ${GREEN}$IMAGEFILE für die VM konfigurieren.${NC}"
$VBOXPATH storageattach "$VMNAME" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$IMAGEFILE"

echo -e "- ${GREEN}Virtuelles DVD-Laufwerk erstellen.${NC}"
$VBOXPATH storageattach "$VMNAME" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium emptydrive

echo -e "- ${GREEN}ISO der Gasterweiterungen einbinden.${NC}"
$VBOXPATH storageattach "$VMNAME" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium additions

echo -e "- ${GREEN}Netzwerkadapter konfigurieren.${NC}"
if [ "$NICTYPE" = "nat" ]; then
 $VBOXPATH modifyvm "$VMNAME" --nic1=$NICTYPE
else
 $VBOXPATH modifyvm "$VMNAME" --nic1=$NICTYPE --bridge-adapter1="$NICDEVICE"
fi

echo -e "- ${GREEN}Datenaustausch konfigurieren (Clipboard, Drag-n-Drop).${NC}"
$VBOXPATH modifyvm "$VMNAME" --clipboard=bidirectional
$VBOXPATH modifyvm "$VMNAME" --draganddrop=bidirectional

echo -e "- ${GREEN}EFI aktivieren.${NC}"
$VBOXPATH modifyvm "$VMNAME" --firmware efi

echo -e "- ${GREEN}RAM konfigurieren.${NC}"
$VBOXPATH modifyvm "$VMNAME" --memory 4096

echo -e "- ${GREEN}VRAM konfigurieren.${NC}"
$VBOXPATH modifyvm "$VMNAME" --vram 120

echo -e "- ${GREEN}Anzahl der CPUs.${NC}"
$VBOXPATH modifyvm "$VMNAME" --cpus 2

echo -e "${GREEN}Windows-Installation beendet.${NC}"

fi


