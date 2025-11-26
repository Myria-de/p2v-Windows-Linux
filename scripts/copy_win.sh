#!/bin/bash
echo "Kopiere Windows-Partition $1 nach /dev/nbd0p1"
sudo sh -c "wimcapture --config=exclude.ini --compress=none --pipable $1 - | wimapply - /dev/nbd0p1"
