#!/bin/bash
sudo rmmod kvm_intel
sudo rmmod kvm
sudo systemctl start vboxdrv 
