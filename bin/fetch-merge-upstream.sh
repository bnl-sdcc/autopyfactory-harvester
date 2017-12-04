#!/bin/bash

set -xe 

cd ~/git/panda-harvester
git fetch upstream
git merge upstream/master
git checkout master
echo "Do a git push..."