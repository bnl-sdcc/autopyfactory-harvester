#!/bin/bash
~/harvester/etc/rc.d/init.d/panda_harvester stop 
killall condor_master 
cd ~/ 
rm -rf harvester /tmp/harvester.db 
cd ~/git/autopyfactory-harvester 
git pull 
cd 
install-apfharvester-user.sh