# p2v-Windows-Linux
Wer Linux neben Windows auf dem PC installiert, muss neu booten, wenn einmal eine Windows-Anwendung benötigt wird. Mit einem virtualisierten Windows kann man Windows-Programme auch unter Linux nutzen.


## Voraussetzungen und Einschränkungen
Virtualisierungserweiterungen prüfen:
```
sudo apt install cpu-checker
```
```
kvm-ok
```
## Vorüberlegungen und Vorbereitungen
Die Script-Dateien zu diesem Artikel nehmen Ihnen einen Teil der Arbeit unter Linux ab. Laden Sie über über https://m6u.de/P2VWIN unter „Releases“ die Datei „Windows-VM.tar.gz“ herunter, die Sie in den Ordner „/home/[user]/Windows-VM“ entpacken. Wenn Sie Qemu/KVM verwenden möchten, benötigen Sie eine ISO-Datei mit Windows-Treibern. Laden Sie die Datei „virtio-win-0.1.285.iso“ über https://m6u.de/VIRTWIN herunter. Speichern Sie die Datei im Ordner „/home/[user]/Windows-VM/drivers“.

**Festplattenspeicher für Qemu/KVM:** Der Virtualisierer benötigt Lese- und Schreibzugriff in den Ordnern für virtuelle Maschinen und ISO-Dateien. Abhängig von der Systemkonfiguration ist der verwendeten Gruppe „libvirt-qemu“ der Zugriff auf Ihr Home-Verzeichnis oder auf unter „/media/[User]“ eingehängte USB-Laufwerke nicht erlaubt. Es ist am einfachsten, den Ordner „/home/[user]/Windows-VM“ in das Hauptverzeichnis „/“ zu kopieren und die nötigen Rechte zu vergeben. Starten Sie dafür 
```
~/Windows-VM/Tools/copy_to_root.sh
```
Verwenden Sie den Ordner „/Windows-VM“ dann auch als Speicherort für Image-Dateien und VMs. Sie können den Ordner bei Bedarf auf eine andere Festplatte kopieren, die etwa unter „/mnt/[Partition]“ eingehängt ist. Passen Sie dafür die Pfade in „copy_to_root.sh“ an.

## Partition unter Windows kopieren
Disk2vhd (https://m6u.de/D2VHD) ist ein bewährtes Tool von Microsoft. Sie erstellen damit ein Backup von Laufwerken beziehungsweise Partitionen in einer VHD- oder VHDX-Datei (Virtual Hard Disk). Wenn möglich, verwenden Sie das ältere VHD-Format, das sich in Virtualbox direkt verwenden lässt. Es ist allerdings auf Partitionsgrößen bis 2 TB beschränkt. Eine VHDX-Datei müssen Sie in jedem Fall in ein Format konvertieren, das Virtualbox oder Qemu/KVM unterstützen.

## P2V mit einer VHD(X)-Datei ohne Grub
Wenn die VHD(X)-Datei nur den Windows-Bootloader ohne Grub enthält, verwenden Sie unser Script „p2v_from_vhd.sh“ (https://m6u.de/P2VWIN). Andernfalls lesen Sie zuerst den nächsten Punkt. Öffnen Sie das Script in einem Texteditor. Die kommentierten Variablen im Konfigurationsabschnitt bestimmen die Arbeitsweise. Passen Sie alle Pfade hinter den Variablen für Ihr System an. Die Variable „VMNAME“ enthält die Bezeichnung für die neue VM, beispielsweise „Windows10“. Mit „VMTYPE=QEMU“ oder „VMTYPE=VBOX“ legen Sie die Virtualisierungssoftware fest, die Sie verwenden möchten.

Das Tool qemu-img für die Konvertierung der VHD/VHDX-Datei installieren Sie mit
```
sudo apt install qemu-utils
```
Nach diesen Vorbereitungen starten Sie das Script aus dem Ordner „Windows-VM“ im Terminal mit
```
./p2v_from_vhd.sh
```
Eine VHD-Datei kann man direkt in Virtualbox verwenden, weshalb eine Konvertierung nur für Qemu/KVM nötig ist. Eine VHDX-Datei wird in das Qcow2-Format und für Virtualbox in das VDI-Format überführt. Danach erstellt das Script automatisch eine virtuelle Maschine, die Sie in Virtualbox oder dem Virtual Machine Manager (Qemu/KVM) starten können.

## Bootmanager in der VHD(X)-Datei wiederherstellen
Stammt die VHD- oder VHDX-Datei von einem PC mit parallel installiertem Linux, stellen Sie zuerst die Windows-Bootumgebung wieder her. Diese Aufgabe erledigt das Script „repair_winboot.sh“, das zusätzlich das Python-Script „p2v_windows.py“ verwendet. Dieses benötigt weitere Module, die Sie zuerst mit „install_deps_venv.sh“ einrichten müssen.
Öffnen Sie „repair_winboot.sh“ in einem Texteditor und tragen Sie hinter „IMAGEFILE=“ Pfad und Dateinamen zur VHD- oder VHDX-Datei ein. Starten Sie das Bash-Script mit
```
./repair_winboot.sh
```
Das Script erzeugt für die Imagedatei das Gerät „/dev/nbd0“ und liefert mit „sudo parted -l“ eine Liste der enthaltenen Partitionen. Typisch ist eine Partition mit der Nummer „1“ und den Flags „boot, esp“ (Uefi-Partition) und „3“, eine NTFS-Partition mit dem Flag „msftdata“ (Windows-Partition). In diesem Fall konfigurieren Sie im Script
```
NBDEFIPART=1
NBDWINPART=3
```
Passen Sie die Partitionsnummern an, wenn die Ausgabe bei Ihnen anders lautet. Danach starten Sie das Script erneut. Anschließend erstellen Sie mit „p2v_from_vhd.sh“ eine virtuelle Maschine, wie im vorherigen Punkt beschrieben.

## Windows-Partition unter Linux kopieren
Das Tool Wimlib-Imagex (https://wimlib.net) kann NTFS-Partitionen unter Linux in einer WIM-Datei sichern (Windows Imaging). Der Nachteil: Wimlib-Imagex ist nicht fehlertolerant. Wenn das Tool eine Datei nicht lesen oder schreiben kann, etwa aufgrund von Fehlern im Dateisystem, bricht es den Vorgang ab. Man muss dann die betroffenen Dateien oder Ordner in einer Ausnahmeliste vermerken und von vorn beginnen.
Die Befehlszeile
```
wimcapture --config=exclude.ini --compress=none --pipable [Quelle] - | wimapply – [Ziel]
```
kopiert die Partition „[Quelle]“ auf die Partition „[Ziel]“. Die Datei „exclude.ini“ enthält die Ausnahmeliste. 
Für P2V verwenden Sie unser Script „p2v_from_HDD.sh“. Starten Sie zuerst „install_deps_venv.sh“, um die nötigen Tools und Python-Module einzurichten. Öffnen Sie das Script in einem Texteditor und bearbeiten Sie den Konfigurationsabschnitt. „WINPART=“ verweist auf die Windows-Partition, beispielsweise „/dev/sda3“. Sie ermitteln die Partition mit
```
sudo parted -l
```
Hinter „IMAGESIZE=“ tragen Sie die Größe der Imagedatei ein. Dieses muss etwas größer sein als die ursprüngliche Windows-Partition. Darunter stehen Variablen für die Konfiguration von Qemu/KVM oder Virtualbox. Orientieren Sie sich für die Anpassungen an den Kommentaren.
Starten Sie das Script im Terminal mit
```
./p2v_from_HDD.sh
```
Es kopiert die Windows-Partition und erstellt eine virtuelle Maschine. Sollte dabei ein Fehler auftreten, fügen Sie den angezeigten Pfad in die Datei „exclude.ini“ ein und starten das Script noch einmal.


## Qemu/KVM und Virtualbox nebeneinander nutzen
Wer beide Virtualisierungsprogramme verwenden möchte, etwa um die Funktionen auszuprobieren, kann beide installieren. Bei der gleichzeitigen Nutzung kann es jedoch zu Problemen kommen.

Die Ursache dafür sind die KVM-Kernel-Erweiterungen (ab Kernel 6.12), mit denen Virtualbox zurzeit nicht korrekt zusammenarbeitet. Beim Start einer VM erhalten Sie nur die Fehlermeldung „VT-x is being used by another hypervisor“ oder ähnlich. Sollte der Fehler nicht inzwischen behoben sein, öffnen Sie die Datei „/etc/default/grub“ mit administrativen Rechten und passen die Variable „GRUB_CMDLINE_LINUX“ an. Die Zeile sieht dann so aus:
```
GRUB_CMDLINE_LINUX="kvm.enable_virt_at_load=0"
```
Speichern Sie die Datei und starten Sie im Terminal
```
sudo update-grub
```
Starten Sie Linux neu. 

In Virtualbox lässt sich eine VM dann starten und in Qemu/KVM ebenfalls – allerdings nicht gleichzeitig. Sie können nur jeweils eins der Programme verwenden.

Im Verzeichnis "Tools" finden Sie das Script "disable_KVM_enable_Vbox.sh", über das Sie das Kernel-Modul jederzeit entladen können. Das Script "enable_KVM_disable_vbox.sh" lädt das Modul bei Bedarf wieder.




