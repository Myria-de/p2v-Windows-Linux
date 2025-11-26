#!/bin/bash
sudo systemctl stop vboxdrv
sudo modprobe kvm
sudo modprobe kvm-intel 
