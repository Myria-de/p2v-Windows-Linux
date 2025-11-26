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

## Windows in der VM optimieren
Eine virtuelle Maschine hat nur wenig mit der tatsächlichen Hardware im PC gemein. Sie müssen daher die Treiber für den genutzten Virtualisierer installieren. 

**Qemu/KVM:** In die von uns konfigurierte VM ist die ISO-Datei „virtio-win-0.1.285.iso“ mit den nötigen Programmen bereits eingebunden und über den Windows-Explorer als CD-Laufwerk erreichbar. Starten Sie „virtio-win-gt-x64.msi“ und danach „virtio-win-guest-tools.exe“. Starten Sie Windows neu. Sie können jetzt eine höhere Bildschirmauflösung einstellen und die Zwischenablage für den Datenaustausch zwischen Windows und Linux verwenden.

**Virtualbox:** Das Medium mit den Gasterweiterungen ist bereits eingehängt und Sie starten unter Windows „VboxWindowsAdditions.exe“. Nach einem Windows-Neustart steht eine höhere Bildschirmauflösung zur Verfügung und über die Zwischenablage können Sie Daten zwischen beiden Systemen austauschen.

**Jede VM:** Prüfen Sie in der Einstellungen-App unter „Apps“, ob noch unnötige Software vorhanden ist. Entfernen Sie etwa Treiberpakete, die in der virtuellen Maschine ohnehin nicht genutzt werden.

**Netzwerkkonfiguration:** Standardmäßig haben virtuelle Maschinen Internetzugang, aber keinen Zugriff auf Freigaben im lokalen Netzwerk. Wenn Windows 10 keine Sicherheitsupdates mehr erhält, sollten Sie den virtuellen Netzwerkadapter und damit den Internetzugang deaktivieren.

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

## Ergänzende Informationen
Nachfolgend einige Informationen zu Qemu und Virtualbox.

## Qemu/KVM installieren
Die Infrastruktur der KVM-Virtualisierung besteht aus mehreren Programmen und Bibliotheken. Für die Installation unter Ubuntu oder Linux Mint genügt im Terminal die Zeile
```
sudo apt install virt-manager
```
Die zusätzlich erforderlichen Pakete werden automatisch installiert. Das Programm Virtual Machine Manager (VMM) aus dem Paket „virt-manager“ stellt die Benutzeroberfläche zum Erstellen und Verwalten von virtuellen Maschinen bereit. In einem deutschsprachigen Ubuntu oder Linux Mint findet man ihn unter der Bezeichnung „Virtuelle Maschinenverwaltung“.

Um die KVM-Virtualisierung verwenden zu können, müssen Benutzerkonten zur Gruppe „libvirt“ gehören. Der aktuell angemeldete Benutzer wird automatisch zur Gruppe hinzugefügt. Weitere Benutzer fügen Sie mit
```
sudo usermod -aG libvirt [User]
```
hinzu. Setzen Sie den Benutzernamen für den Platzhalter „[User]“ ein.
Starten Sie Linux neu, damit die Änderungen in der Konfiguration wirksam werden.

## Qemu: Datenaustausch mit dem Hostsystem
Die Zwischenablage verwenden Host- und Gastsystem gemeinsam. Text und Bilder lassen sich in beide Richtungen ohne besondere Konfiguration per Strg-C und Strg-V übertragen. Voraussetzung dafür ist die Installation der 

Das Netzwerk der virtuellen Maschinen ist standardmäßig als NAT mit eigenem IP-Bereich konfiguriert. Der Zugriff auf das Internet ist möglich und auch auf Freigaben im lokalen Netzwerk. Der Host-PC kann eine Verbindung zur IP-Adresse des Gast-PCs aufbauen, etwa für SSH oder eine Webserver. VMs sehen sich untereinander nicht und auch über andere Rechner im lokalen Netzwerk ist keine Verbindung möglich. Wenn Sie das ändern möchten, richten Sie eine Netzwerkbrücke ein. Das funktioniert problemlos mit allen Ethernet-Adaptern, mit WLAN-Adaptern jedoch oft nicht.

Falls noch nicht vorhanden installieren Sie die nötige Software mit
```
sudo apt install bridge-utils
```
und starten unter Ubuntu oder Linux Mint im Terminal
```
nm-connection-editor
```
Klicken Sie auf die „+“-Schaltfläche, wählen Sie „Bridge“ und klicken Sie auf „Erstellen“. Hinter „Name der Schnittstelle“ tragen Sie br0 ein. Klicken Sie auf „Hinzufügen“, wählen Sie „Ethernet“ und klicken Sie auf „Erstellen“. Hinter „Geräte“ wählen Sie den Ethernet-Adapter, klicken auf „Speichern“ und dann noch einmal auf „Speichern“. Entfernen Sie „Ethernet-Verbindung 1“ per Klick auf die „-“-Schaltfläche.

In einem anderen Terminal starten Sie den Netzwerk-Manager neu:
```
sudo systemctl restart NetworkManager
```
Manchmal ist es auch nötig Linux neu zu starten, damit die Einstellungen wirksam werden.
Kontrollieren Sie die Konfiguration im Terminal mit
```
ip a
```
„br0“ sollte jetzt eine IP-Adresse aus dem Bereich Ihres Router erhalten haben.

Rufen Sie die Konfiguration Ihrer virtuellen Maschine auf und wählen Sie beim Netzwerkadapter hinter „Netzwerkquelle“ den Eintrag „Bridge device“. Hinter „Gerätename“ tragen Sie *br0* ein und klicken auf „Apply“. Starten Sie das System in der VM neu. Es erhält per DHCP eine IP-Adresse vom Router und ist damit von jedem Gerät im Netzwerk aus erreichbar.

## Virtualbox installieren
Die aktuelle Version von Virtualbox erhalten Sie für alle Betriebssysteme unter www.virtualbox.org/wiki/Downloads. Zu den Varianten für die unterschiedlichen Linux-Distributionen führt dort der Link "Linux distributions". Den Download installieren Sie dann nach Rechtsklick mit dem Paketmanager der Distribution. Alternativ finden Sie auf der Seite auch Informationen zum Einbinden der Paketquelle. Darüber lassen sich dann später auch Updates über den Paketmanager durchführen.

Auf der allgemeinen Downloadseite erscheint auch das "Oracle VM VirtualBox Extension Pack". Dieses darf aus lizenzrechtlichen Gründen nicht mit dem freien Virtualbox ausgeliefert werden, ist aber für private Nutzung frei und kostenlos. Nach dem Download dieses Erweiterungspakets starten Sie Virtualbox und gehen im Virtualbox Manager auf "Erweiterungspakete". Klicken Sie auf die Schaltfläche "Installieren" und navigieren zum Download. Da der Dialog nur Dateien mit der Extension ".vbox-extpack" anzeigt, ist die Auswahl einfach und eindeutig. Nach einem Warnhinweis startet die Installation. Das Erweiterungspaket ist zwar optional, aber für häufige Virtualbox-Nutzung uneingeschränkt zu empfehlen.

**Gruppenzuweisung:** Eine letzte Aktion vervollständigt die Installation unter Linux: Fügen Sie die Systembenutzer, die Virtualbox verwenden sollen, zur Gruppe „vboxusers“ hinzu:
```
sudo adduser [User] vboxusers
```
„[User]“ ersetzen Sie durch den Kontonamen des Benutzers. Wiederholen Sie den Befehl für alle gewünschten Konten. Melden Sie sich dann bei Linux ab und wieder an oder starten Sie das System neu. Diese vollständige Installation mit Erweiterung und Gruppenzuweisung ist für eine sporadische Nutzung von Virtualbox nicht zwingend, erspart aber eventuelle spätere Irritationen - insbesondere beim Versuch, USB-Geräte in einer VM zu nutzen. 

**Gasterweiterungen in die VM installieren**: Im Unterschied zum allgemeinen Virtualbox-Erweiterungspaket werden die Gasterweiterungen in die jeweilige VM installiert. Gasterweiterungen sind optional, aber mindestens für häufiger genutzte VMs zu empfehlen. Sie enthalten Treiber für die Maus und den virtuellen Grafikadapter, verbessern damit Bildschirmauflösung, Skalierung, Mausverhalten und erlauben direkte Ordnerfreigaben zwischen Hostsystem und Gast-VM.

Die Gasterweiterungen lädt Virtualbox in das virtuelle DVD-Laufwerk einer laufenden VM, wenn Sie auf das VM-Fenstermenü "Geräte -> Gasterweiterungen einlegen" klicken. Falls die Menüleiste im Vollbild oder im skalierten Anzeigemodus nicht zugänglich ist, verwenden Sie den Hotkey Host-Pos1 (also standardmäßig Strg-Rechts-Pos1). Das Installationspaket erscheint dann im DVD-Laufwerk der VM, und in einer Windows-VM genügt dann der Doppelklick auf „VBoxWindowsAdditions.exe“. Unter Linux müssen eventuell mit dem Terminal zum Pfad des DVD-Ordners navigieren und dann mit 
```
sudo ./VboxLinuxAdditions.run
```
die Installation starten.

## Virtualbox: Netzwerkbrücke statt NAT
Standardmäßig gilt für VMs wie bei allen Virtualisierern der "NAT"-Modus im Netzwerk: Dabei dient Virtualbox selbst als virtueller Router und weist der VM eine zufällige IP-Adresse zu. Damit kommt die VM ins Internet, bleibt aber im lokalen Heimnetz isoliert. Es ist der VM zwar möglich, sich über die IP-Adressen des Heimnetzes mit Samba- oder SSH-Server zu verbinden, umgekehrt ist aber keine Verbindung zur VM möglich (SSH, Samba, VNC, RDP, Apache…). 

Wenn eine VM einen Dienst im Heimnetz anbieten soll, ist eine andere Einstellung erforderlich. Möglichkeiten gibt es mehrere, aber die einfachste erfordert nur einen einzigen Klick und sollte in den meisten Fällen genügen. Gehen Sie bei einer eingerichteten VM nach "Ändern" auf das "Netzwerk". Hier finden Sie unter "Netzwerk -> Angeschlossen an" eine Reihe weiterer Optionen. Mit „Netzwerkbrücke“ verbindet sich eine VM direkt mit dem Heimnetz. Die VM erhält also vom Heimrouter via DHCP eine lokale IP-Adresse genau wie ein physischer Rechner. Das macht die VM zum gleichberechtigten Mitglied des lokalen Netzes, und sie kann dann von jedem anderen Gerät erreicht werden. Die Umstellung von "NAT" zu "Netzwerkbrücke" kann im Virtualbox Manager jederzeit und auch für eine aktuell laufende VM erfolgen.

**Gemeinsamer Ordner:** Schadsoftware in der VM kann dann allerdings ungeschützte Dateifreigaben infizieren. Die Verwendung der Alternative „Gemeinsamer Ordner“ zusammen mit NAT gilt als sicherer, weil nur genau dieser Ordner betroffen sein kann. Voraussetzung dafür sind die installierten Gasterweiterungen

Gehen Sie im Fenster der laufenden VM auf „Geräte -> Gemeinsame Ordner -> Gemeinsame Ordner“. Über die „‬+‭“‬-Schaltfläche bestimmen Sie einen Ordner auf dem Host-PC für den Datenaustausch. Setzen Sie ein Häkchen vor „Automatisch einbinden“. Damit ein Nutzer auf den gemeinsamen Ordner zugreifen darf, fügen Sie ihn im Gastsystem zur Gruppe „vboxsf“ hinzu:
```
sudo usermod -aG vboxsf [User]
```
„[User]“ ersetzen Sie durch den Benutzernamen des gewünschten Benutzers. Starten Sie das Gastsystem neu. Den gemeinsamen Ordner finden Sie unter Linux im Navigationsbereich des Dateimanagers mit dem Präfix „sf_“. Unter Windows erreichen Sie den Ordner im Windows-Explorer über „‬Netzwerk‭“ ‬und‭ „‬Vboxsrv‭“.

Virtualbox bietet über „Maschine -> Dateimanager“ eine weitere Methode für den Datenaustausch. Geben Sie rechts unter Benutzername und Passwort für die Anmeldung im Gastsystem ein und klicken Sie auf „Sitzung öffnen“. Die Dateisysteme von Host- und Gast-PC werden nebeneinander angezeigt, über die Schaltflächen in der Mitte lassen sich markierte Elemente übertragen.


