#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Script based on https://codeberg.org/regnarg/deploy-win10-from-linux
import sys,os,shutil
import parted
import time
import string
import tempfile
import argparse
import textwrap
import subprocess
from subprocess import Popen, PIPE
from shlex import split
from pathlib import Path
from contextlib import *

ESP_SIZE = 300 # MiB
efi=True
class bcolors:
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    NC = '\033[0m'

def part_path(dev, partno):
    dev = Path(dev)
    return dev.parent / f"{dev.name}{'p' if dev.name[-1] in string.digits else ''}{partno}"

@contextmanager
def with_device(pth):
    pth = Path(pth)
    if pth.is_file():
        r = subprocess.run(['losetup', '--show', '-f', '-P', pth], check=True, capture_output=True)
        dev = Path(r.stdout.decode('ascii').strip())
        if not dev.is_block_device():
            raise RuntimeError(f"Cannot find loop device {dev}")
        try:
            yield dev
        finally:
            subprocess.run(['losetup', '-d', dev])
    elif pth.is_block_device():
        time.sleep(1)
        subprocess.run(['partprobe', pth])
        time.sleep(1)
        yield pth
    else:
        raise Exception(f"'{pth}' is neither a file nor a block device")

@contextmanager
def with_mounted(part, *, fs='ntfs'):
    part = Path(part)
    with ExitStack() as es:
        dir = Path(tempfile.mkdtemp(prefix=f"win10_mnt_{part.name}_"))
        es.callback(lambda: dir.rmdir())
        if fs == 'ntfs':
            cmd = ['ntfs-3g', '-o', 'remove_hiberfile', str(part), dir]
        elif fs == 'fat':
            cmd = ['mount', '-t', 'vfat', str(part), dir]
        subprocess.run(cmd, check=True)
        es.callback(lambda: subprocess.run(['umount', dir]))
        yield dir

def ci_lookup(base, *comps, creating=False, parents=False, mkdir=False):
    """Lookup path components case-insensitively"""
    cur = Path(base)
    for idx, comp in enumerate(comps):
        cands = [ item for item in cur.iterdir() if  item.name.lower() == comp.lower() ]
        if not cands:
            if (creating or mkdir) and idx == len(comps) - 1:
                cur = cur / comp
                if mkdir:
                    cur.mkdir(exist_ok=True)
                break
            elif parents and idx < len(comps) - 1:
                cur = cur / comp
                cur.mkdir()
                continue
            else:
                raise FileNotFoundError(f"'{comp}' not found case-insensitively in '{cur}'")
        elif len(cands) > 1:
            raise RuntimeError(f"Multiple case-insensitive candidates for '{comp}' in '{cur}': {cands}")
        else:
            cur = cands[0]
    return cur

def create_partitions(dev, *, efi=False):
    with open(dev, 'r+b') as fh:
        fh.write(bytearray(1024*1024)) # clear MBR and other metadata

    device = parted.Device(str(dev))
    if efi:
        ptype = 'gpt'
        esp_sec = parted.sizeToSectors(ESP_SIZE, "MiB", device.sectorSize)
        end_pad = parted.sizeToSectors(1, "MiB", device.sectorSize) # leave space for secondary part table at the end
        extra_space = esp_sec + end_pad
    else:
        ptype = 'msdos'
        extra_space = 0


    disk = parted.freshDisk(device, ptype)
    start = parted.sizeToSectors(1, "MiB", device.sectorSize)
    geometry = parted.Geometry(device=device, start=start,
                               length=device.getLength() - start - extra_space)
    filesystem = parted.FileSystem(type='ntfs', geometry=geometry)
    partition = parted.Partition(disk=disk, type=parted.PARTITION_NORMAL,
                                 fs=filesystem, geometry=geometry)
    disk.addPartition(partition=partition,
                      constraint=device.optimalAlignedConstraint)

    if not efi:
        partition.setFlag(parted.PARTITION_BOOT)

    if efi: # create ESP
        geometry = parted.Geometry(device=device, start=device.getLength() - esp_sec - end_pad,
                                   length=esp_sec)
        filesystem = parted.FileSystem(type='fat32', geometry=geometry)
        partition = parted.Partition(disk=disk, type=parted.PARTITION_NORMAL,
                                     fs=filesystem, geometry=geometry)
        disk.addPartition(partition=partition,
                          constraint=device.optimalAlignedConstraint)
        partition.setFlag(parted.PARTITION_BOOT)

    disk.commit()
    
def format_part(part):
    cmd = ['mkntfs', '-vv', '-f', '-S', '63', '-H', '255', '--partition-start', '2048', str(part)]
    print("Format Partion:", cmd)
    subprocess.run(cmd, check=True)

def setup_vbr(part):
    subprocess.run(['ms-sys', '-f', '--ntfs', str(part)], check=True)

def copy_boot_files(dir):
    shutil.copy(ci_lookup(dir, 'Windows', 'Boot', 'PCAT', 'bootmgr'), ci_lookup(dir, 'bootmgr', creating=True))
    boot_dir = ci_lookup(dir, 'Boot', creating=True)
    boot_dir.mkdir(exist_ok=True)
    shutil.copy(Path(__file__).parent / 'BCD', ci_lookup(boot_dir, 'BCD', creating=True))

def copy_efi_files(win_mnt, esp_mnt):
    efi_boot = ci_lookup(esp_mnt, 'EFI', 'Boot', mkdir=True, parents=True)
    efi_ms = ci_lookup(esp_mnt, 'EFI', 'Microsoft', mkdir=True, parents=True)
    efi_ms_boot = ci_lookup(efi_ms, 'Boot', mkdir=True)
    efi_ms_boot_res = ci_lookup(efi_ms_boot, 'Resources', mkdir=True)
    efi_ms_boot_fonts = ci_lookup(efi_ms_boot, 'Fonts', mkdir=True)
    efi_ms_recovery = ci_lookup(efi_ms, 'Recovery', mkdir=True)
    win_boot = ci_lookup(win_mnt, 'Windows', 'Boot')
    win_boot_efi = ci_lookup(win_boot, 'EFI')
    win_boot_res = ci_lookup(win_boot, 'Resources')
    win_boot_fonts = ci_lookup(win_boot, 'Fonts')
    bootmgfw = ci_lookup(win_boot_efi, 'bootmgfw.efi')
    bootx64 = ci_lookup(efi_boot, 'bootx64.efi', creating=True)
    shutil.copy(bootmgfw, bootx64)
    shutil.copytree(win_boot_efi,   efi_ms_boot,       dirs_exist_ok=True)
    shutil.copytree(win_boot_res,   efi_ms_boot_res,   dirs_exist_ok=True)
    shutil.copytree(win_boot_fonts, efi_ms_boot_fonts, dirs_exist_ok=True)
    shutil.copy(Path(__file__).parent / 'BCD-efi', ci_lookup(efi_ms_boot, 'BCD', creating=True))


class MyArgumentParser(argparse.ArgumentParser):
    def print_help(self, file=None):
        if file is None:
            file = sys.stdout
        message = textwrap.dedent('''Hilfe: p2v_qemu.py
        Das Script erstellt eine ESP- und eine Windows-Partition
        auf der virtuellen Festplatte /dev/nbd0.
        Danach kopiert es die mit --winpart angegebene Partition 
        auf die virtuelle Partition.
        Oder es kopiert den Inhalt der über --wimfile angegebenen Datei 
        auf diese Partition.
        
         --disk PATH (nbd-Pfad wie /dev/nbd0)
         [--winpart Partition] (die Windows-Partition wie /dev/sdb3)         
         oder
         [--wimfile WIM-File Name] (Pfad wie /mnt/sdc1/backup.wim)
        ''')

        file.write(message+"\n")

    def print_usage(self, file=None):
        if file is None:
            file = sys.stdout
        message = textwrap.dedent('''usage: p2v_qemu.py
         --disk PATH (nbd-Pfad wie /dev/nbd0)
         [--winpart Partition] (die Windows-Partition wie /dev/sdb3)         
         oder
         [--wimfile WIM-File Name] (Pfad wie /mnt/sdc1/backup.wim)
        ''')
        file.write(message+"\n")
def main():
    parser = MyArgumentParser(
    #add_help=False,
    prog="p2v_qemu.py",
    description="",
    )
    parser.add_argument("--disk", "-d", type=str, default="", help = "nbd device path",required=True)
    parser.add_argument("--winpart","-w", type=str, default="", help = "Windows Partition")
    parser.add_argument("--wimfile", "-f", type=str, default="", help = "Bereits erfasste WIM-Datei")
    parser.add_argument("--qcow2file", "-q", type=str, default="", help = "Nur Windows-Bootmanager einrichten")
    parser.add_argument("--nbdefipart", "-e", type=str, default="", help = "EFI-Partition in der qcow2-Datei")
    parser.add_argument("--nbdwinpart", "-n", type=str, default="", help = "Windows-Partition in der qcow2-Datei")

    args = parser.parse_args().__dict__
    disk = args["disk"]
    WINPATH = args["winpart"]
    WIMFILE = args["wimfile"]
    QCOW2FILE = args["qcow2file"]
    NBDEFIPART = args["nbdefipart"]
    NBDWINPART = args["nbdwinpart"]
    
    if QCOW2FILE != "":
        if NBDEFIPART == "" or NBDWINPART == "":
            print(f"{bcolors.RED}Sie müssen die Partitionsnummern in der qcow2-Datei angeben.{bcolors.NC}")
            print("Beispielsweise 1 (efi) und 3 (Windows).")
            sys.exit(1)

        print(f"{bcolors.GREEN}EFI-Partition vorbereiten.{bcolors.NC}")
        with with_device(disk) as dev:
            part = part_path(dev, NBDWINPART)
            print(f"{bcolors.GREEN}Windows-Partition{bcolors.NC}", part)
            esp = part_path(dev, NBDEFIPART)
            print(f"{bcolors.GREEN}ESP-Partition{bcolors.NC}", esp)
            subprocess.run(['mkfs.fat', '-F32', '-n', 'ESP', str(esp)], check=True)
            print(f"{bcolors.GREEN}Kopiere Boot-Dateien {bcolors.NC}")
            with with_mounted(part) as dir:
                copy_boot_files(dir)
            if efi: # copy EFI boot files
                with with_mounted(part) as win_mnt, with_mounted(esp, fs='fat') as esp_mnt:
                        copy_efi_files(win_mnt, esp_mnt)                
                
    if QCOW2FILE == "":
        if WIMFILE == "" and WINPATH =="":
            print(f"{bcolors.RED}Eine der Optionen --winpart oder --wimfile muss angegeben sein.{bcolors.NC}")
            sys.exit(1)

        if WIMFILE != "" and WINPATH !="":
            print(f"{bcolors.RED}Nur eine der Optionen --winpart oder --wimfile darf angegeben sein.{bcolors.NC}")
            sys.exit(1)
        
        create_partitions(disk, efi=efi)

        with with_device(disk) as dev:
            part = part_path(dev, 1)
            print(f"{bcolors.GREEN}Windows-Partition{bcolors.NC}", part)
            esp = part_path(dev, 2)
            print(f"{bcolors.GREEN}ESP-Partition{bcolors.NC}", esp)
            subprocess.run(['mkfs.fat', '-F32', '-n', 'ESP', str(esp)], check=True)
            format_part(part)
            #subprocess.check_call(['./copy_win.sh', WINPATH])
            if WINPATH != "":
                subprocess.run(['partclone.ntfs', '-N', '-c', '-d', '-b', '-s', str(WINPATH), '-O', str(part)], check=True)
            if WIMFILE != "":
                subprocess.run(['wimapply', str(WIMFILE), str(part)], check=True)
                
            setup_vbr(part)
            with with_mounted(part) as dir:
                copy_boot_files(dir)
            if efi: # copy EFI boot files
                with with_mounted(part) as win_mnt, with_mounted(esp, fs='fat') as esp_mnt:
                    copy_efi_files(win_mnt, esp_mnt)

if __name__ == '__main__':
    main() 
