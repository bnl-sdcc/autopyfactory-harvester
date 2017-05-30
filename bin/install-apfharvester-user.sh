#!/bin/bash
#
# on RHEL7
#
echo virtualenv harvester
virtualenv harvester
echo cd harvester
cd harvester
echo . bin/activate
. bin/activate
echo pip install pip --upgrade
pip install pip --upgrade
echo pip install python-daemon
pip install python-daemon --upgrade
echo pip install requests
pip install requests --upgrade
echo pip install git+git://github.com/PanDAWMS/panda-common.git@setuptools
pip install git+git://github.com/PanDAWMS/panda-common.git@setuptools --upgrade
#echo pip install git+git://github.com/PanDAWMS/panda-harvester.git
#pip install git+git://github.com/PanDAWMS/panda-harvester.git --upgrade

echo pip install git+git/github.com/bnl-sdcc/panda-harvester  --upgrade
pip install git+git://github.com/bnl-sdcc/panda-harvester  --upgrade
sleep 2

echo cp ~/git/autopyfactory-harvester/configs/jrh-panda_harvester.init etc/rc.d/init.d/panda_harvester
cp ~/git/autopyfactory-harvester/configs/jrh-panda_harvester.init etc/rc.d/init.d/panda_harvester
echo cp ~/git/autopyfactory-harvester/configs/jrh-panda_common.cfg etc/panda/panda_common.cfg
cp ~/git/autopyfactory-harvester/configs/jrh-panda_common.cfg etc/panda/panda_common.cfg
echo cp ~/git/autopyfactory-harvester/configs/jrh-panda_harvester etc/sysconfig/panda_harvester
cp ~/git/autopyfactory-harvester/configs/jrh-panda_harvester etc/sysconfig/panda_harvester
echo cp~/git/autopyfactory-harvester/configs/jrh-panda_harvester.cfg  etc/panda/panda_harvester.cfg
cp ~/git/autopyfactory-harvester/configs/jrh-panda_harvester.cfg  etc/panda/panda_harvester.cfg
echo cp ~/git/autopyfactory-harvester/configs/jrh-panda_queueconfig.json etc/panda/panda_queueconfig.json
cp ~/git/autopyfactory-harvester/configs/jrh-panda_queueconfig.json etc/panda/panda_queueconfig.json

chmod +x etc/rc.d/init.d/panda_harvester
mkdir -p log  
mkdir -p var/log/panda/
mkdir -p var/run
mkdir -p tmp

echo PATH=$PATH
echo PYTHONPATH=$PYTHONPATH
echo PANDA_HOME=$PANDA_HOME

echo "cd etc ; wget -nc https://gitlab.cern.ch/plove/rucio/raw/7121c7200257a4c537b56ce6e7e438f0b35c6e48/etc/web/CERN-bundle.pem ; cd ../"
cd etc ; wget -nc https://gitlab.cern.ch/plove/rucio/raw/7121c7200257a4c537b56ce6e7e438f0b35c6e48/etc/web/CERN-bundle.pem ; cd ../

echo voms-proxy-init -voms atlas:/atlas/usatlas/Role=production
voms-proxy-init -voms atlas:/atlas/usatlas/Role=production -out /tmp/harvesterproxy

echo Starting init script...
etc/rc.d/init.d/panda_harvester start

