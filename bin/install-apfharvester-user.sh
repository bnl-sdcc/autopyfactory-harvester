#!/bin/bash
#
# Fast and dirty
# APF Grid Harvester setup
# on RHEL7
#
# John Hover <jhover@bnl.gov>
#

cd ~/
echo virtualenv harvester
virtualenv harvester

echo cd harvester
cd harvester

echo . bin/activate
. bin/activate

# Install, run personal condor
mkdir tmp ; cd tmp
wget http://dev.racf.bnl.gov/dist/condor/condor-8.6.3-x86_64_RedHat7-stripped.tar.gz
tar -xvzf condor-8.6.3-x86_64_RedHat7-stripped.tar.gz
cd condor-8.6.3-x86_64_RedHat7-stripped
./condor_install --prefix ~/harvester/
CHOST=`hostname -s`
CLOCAL=~/harvester/local.$CHOST/condor_config.local
echo cp ~/git/autopyfactory-harvester/configs/jrh-condor_config.local $CLOCAL
cp ~/git/autopyfactory-harvester/configs/jrh-condor_config.local $CLOCAL
. $VIRTUAL_ENV/condor.sh
condor_config_val -config 
condor_master

cd $VIRTUAL_ENV

# Install Harvester
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

echo pip install git+git://github.com/PanDAWMS/autopyfactory.git --upgrade
pip install git+git://github.com/PanDAWMS/autopyfactory.git --upgrade

echo pip install git+git://github.com/PanDAWMS/autopyfactory-tools.git --upgrade
pip install git+git://github.com/PanDAWMS/autopyfactory-tools.git --upgrade

echo pip install git+git://github.com/bnl-sdcc/sdcc-pluginmanager.git --upgrade
pip install git+git://github.com/bnl-sdcc/sdcc-pluginmanager.git --upgrade

echo pip install git+git/github.com/bnl-sdcc/panda-harvester  --upgrade
pip install git+git://github.com/bnl-sdcc/panda-harvester  --upgrade
sleep 2

# Dirs
mkdir -p log
mkdir -p libexec  
mkdir -p var/log/panda/
mkdir -p var/harvester
mkdir -p var/factory/logs
mkdir -p var/run
mkdir -p tmp

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

echo cp ~/git/autopyfactory-harvester/configs/jrh-agisdefaults.conf etc/autopyfactory/agisdefaults.conf
cp ~/git/autopyfactory-harvester/configs/jrh-agisdefaults.conf etc/autopyfactory/agisdefaults.conf

echo cp ~/git/autopyfactory-harvester/configs/jrh-autopyfactory.conf etc/autopyfactory/autopyfactory.conf
cp ~/git/autopyfactory-harvester/configs/jrh-autopyfactory.conf etc/autopyfactory/autopyfactory.conf

echo cp ~/git/autopyfactory-harvester/configs/jrh-auth.conf etc/autopyfactory/auth.conf
cp ~/git/autopyfactory-harvester/configs/jrh-auth.conf etc/autopyfactory/auth.conf

echo cp ~/git/autopyfactory-harvester/libexec/wrapper* libexec/
cp ~/git/autopyfactory-harvester/libexec/wrapper* libexec/

# Houseousekeeping.
chmod +x etc/rc.d/init.d/panda_harvester
chmod +x libexec/wrapper*
ln -s ~/harvester/etc/rc.d/init.d/panda_harvester ~/harvester/etc/init.d
echo "export CONDOR_CONFIG_VAL=$HOME/harvester/bin/condor_config_val" >> ~/harvester/condor.sh

# Environment
echo PATH=$PATH
echo PYTHONPATH=$PYTHONPATH
echo PANDA_HOME=$PANDA_HOME

# Proxy stuff
echo "cd etc ; wget -nc https://gitlab.cern.ch/plove/rucio/raw/7121c7200257a4c537b56ce6e7e438f0b35c6e48/etc/web/CERN-bundle.pem ; cd ../"
cd etc ; wget -nc https://gitlab.cern.ch/plove/rucio/raw/7121c7200257a4c537b56ce6e7e438f0b35c6e48/etc/web/CERN-bundle.pem ; cd ../

echo voms-proxy-init -valid 96:00 -voms atlas:/atlas/usatlas/Role=production
voms-proxy-init -valid 96:00 -voms atlas:/atlas/usatlas/Role=production -out /tmp/harvesterproxy

echo Starting init script...
etc/rc.d/init.d/panda_harvester start
cd

