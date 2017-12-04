#!/bin/bash

set -xe

~/harvester/etc/rc.d/init.d/panda_harvester stop 
killall condor_master 
cd ~/ 
rm -rf harvester /tmp/harvester.db 
cd ~/git/autopyfactory-harvester 
git pull 
./bin/install-apfharvester.sh