#!/bin/bash
echo cd ~/harvester
cd ~/harvester

echo . ./bin/activate
. ./bin/activate

echo . condor.sh
. condor.sh

echo . etc/sysconfig/panda_harvester
. etc/sysconfig/panda_harvester

echo ./etc/rc.d/init.d/panda_harvester stop
./etc/rc.d/init.d/panda_harvester stop

echo condor_rm -all
condor_rm -all

echo sleep 10
sleep 10

echo condor_off -master
condor_off -master
sleep 5