#!/bin/bash
echo cd ~/harvester
cd ~/harvester

echo . ./bin/activate
. ./bin/activate

echo . condor.sh
. condor.sh

echo condor_master
condor_master
sleep 5

echo . etc/sysconfig/panda_harvester
. etc/sysconfig/panda_harvester

echo ./etc/rc.d/init.d/panda_harvester start
./etc/rc.d/init.d/panda_harvester start

echo Done.