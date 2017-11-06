#!/bin/bash
#
# Fast and dirty
# APF Grid Harvester turn off, clean script. 
#
# John Hover <jhover@bnl.gov>
#

echo Uninstalling Harvester. 

echo ~/git/autopyfactory-harvesteer/bin/shutdown-apfharvester.sh
~/git/autopyfactory-harvesteer/bin/shutdown-apfharvester.sh

sleep 5

echo rm -rf ~/harvester
rm -rf ~/harvester

echo Done. 
