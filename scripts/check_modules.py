#!/usr/bin/python3
# check modules installed
import subprocess
import sys
reqs = subprocess.check_output([sys.executable, '-m', 'pip', 'freeze'])
installed_packages = [r.decode().split('==')[0] for r in reqs.split()]
#if not 'clize' in installed_packages:
#     print("Fehler: Paket clize ist nicht installiert")
#     print("Installieren Sie es mit pip3 install clize --user")
#     sys.exit(1)
if not 'construct' in installed_packages:
     print("Fehler: Paket construct ist nicht installiert")
     print("Installieren Sie es mit sudo apt install python3-construct")
     sys.exit(1)
if not 'pyparted' in installed_packages:
     print("Installieren Sie es mit sudo apt install python3-parted")
     print("")
     sys.exit(1)
print("Okay. Alle nötigen Python-Module gefunden")
sys.exit(0)     
