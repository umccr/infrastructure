#!/bin/sh
set -e

echo 'Cleaning up after bootstrapping...'
sudo apt-get -y autoremove
sudo apt-get -y clean
sudo rm -rf /tmp/*
cat /dev/null > ~/.bash_history
#history -c # not found error on AWS ami-74fa3d16 (ubuntu artful)
exit 0
