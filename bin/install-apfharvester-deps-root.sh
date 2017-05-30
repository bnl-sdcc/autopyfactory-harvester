#!/bin/bash
#
# on RHEL7
#
echo yum -y install python-virtualenv
yum -y install python-virtualenv

echo yum -y install condor condor-python
yum -y install condor condor-python

echo yum -y install voms-clients-cpp ca-certificates
yum -y install voms-clients-cpp ca-certificates

echo rpm -ivh  https://repo.grid.iu.edu/osg/3.3/osg-3.3-el7-release-latest.rpm
rpm -ivh  https://repo.grid.iu.edu/osg/3.3/osg-3.3-el7-release-latest.rpm

yum -y install vo-client

echo "DAEMON_LIST = COLLECTOR, MASTER, NEGOTIATOR, SCHEDD >> /etc/condor/config.d/00personal_condor.config"
echo DAEMON_LIST = COLLECTOR, MASTER, NEGOTIATOR, SCHEDD >> /etc/condor/config.d/00personal_condor.config 

echo service start condor
service start condor

echo ps auxf | grep condor
ps auxf | grep condor

echo useradd harvester
useradd harvester

echo Now su -l harvester and run user install. 
