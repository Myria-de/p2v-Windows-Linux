#!/bin/bash
sudo -E cp -R $HOME/Windows-VM /
sudo -E chown -R $USER:libvirt-qemu /Windows-VM
sudo find /Windows-VM -type d -exec chmod 775 {} +
sudo find /Windows-VM -type f -exec chmod 664 {} +
sudo find /Windows-VM -name '*.sh' -exec chmod 775 {} +

