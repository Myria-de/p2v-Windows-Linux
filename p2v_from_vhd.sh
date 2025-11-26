#!/bin/bash
# Erstellt eine QCOW2/VDI-Datei aus einer VHDX-Datei
# ohne Anpassung der Bootumgebung
#####################
### Konfiguration ###
#####################
# Das Verzeichnis, aus dem das Script aufgerufen wurde
# ist das Arbeitsverzeichnis
WORKDIR=`pwd`
# Das Verzeichnis, in dem VMs gespeichert werden
VMDIR=$WORKDIR/VMs
# vhd- oder vhdx-Datei
VHDXFILE=$WORKDIR/WZ490_win_grub.VHDX
# Die eindeutige Bezeichnung für die neue virtuelle Maschine
VMNAME="Windows10-7"
### Konfiguration Qemu ###
VMTYPE=QEMU # VM für Qemu/KVM erstellen
OSVARIANT="win10" # Eine Liste erhalten Sie mit virt-install --osinfo list
## oder
### Konfiguration Virtualbox ###
#VMTYPE=VBOX
# Typ der VM
# VBoxManage list ostypes liefert eine Liste der Typen
# z.B. "Windows10" (32-Bit) "Windows10_64" "Windows11_64" "Windows7_64" "Windows7" (32 Bit)
OSTYPE=Windows10_64
# Netwerkadapter konfigurieren
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
filename=$(basename -- "$VHDXFILE")
extension="${filename##*.}"
extension=${extension,,}

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
 # qemu-img ist installiert?
 if [ -z $(which  qemu-img) ]
 then
  echo -e "${RED}Fehler: Bitte installieren Sie das Paket qemu-utils. Abbruch.${NC}"
  exit 1
 else
  echo -e "${GREEN}Verwende Qemu/KVM.${NC}"
 fi
fi
}

if [ "$VMTYPE" = "QEMU" ]
then
if [ ! -e $WORKDIR/drivers/virtio-win-0.1.285.iso ]
 then
  echo -e "${RED}Fehler: Die Datei $WORKDIR/drivers/virtio-win-0.1.285.iso fehlt.${NC}"
  echo -e "${RED}Download: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads.${NC}"
  exit 1
 fi
fi

##########################################
###      Das Script startet hier       ###
##########################################
# Voraussetzungen prüfen
check_pre

if [ "$VHDXFILE" = "" ]
then
 echo -e "- ${RED}Konfigurieren Sie dieses Script zuerst und geben Sie eine VHD/VHDX-Datei an.${NC}"
 exit 1
fi

if [ "$VMTYPE" = "" ]
then
  echo -e "- ${RED}Geben Sie den Virtualisierer hinter der Variablen VMTYPE= an.${NC}"
  exit 1
fi


if [ ! -d $VMDIR/$VMNAME ]
then
 echo -e "- ${GREEN}Erstelle Verzeichnis $VMDIR/$VMNAME.${NC}"
 mkdir -p $VMDIR/$VMNAME
fi
IMAGEPATH=$VMDIR/$VMNAME

if [ "$VMTYPE" = "QEMU" ]
then
 IMAGEFILE=$IMAGEPATH/$VMNAME.qcow2
 echo -e "- ${GREEN}Konvertiere $VHDXFILE nach $IMAGEFILE.${NC}"
 
 qemu-img convert -p -O qcow2 $VHDXFILE $IMAGEFILE
  
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
 
 # VMM starten
 virt-manager --connect qemu:///system --show-domain-console $VMNAME 
 echo -e "- ${GREEN}Fertig: Qemu-VM $VMNAME.${NC}"
fi

if [ "$VMTYPE" = "VBOX" ]
then
 if [ "$extension" = "vhd" ]
 then
 IMAGEFILE=$VHDXFILE
 echo -e "- ${GREEN}Keine Konvertierung. Verwende $IMAGEFILE.${NC}"
 else
   IMAGEFILE=$IMAGEPATH/$VMNAME.vdi
   echo -e "- ${GREEN}Konvertiere $VHDXFILE nach $IMAGEFILE.${NC}"
   qemu-img convert -p -O vdi $VHDXFILE $IMAGEFILE
 fi

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

