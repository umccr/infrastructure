#!/bin/sh
set -e # make sure any failling command will fail the whole script

echo "Setting up StackStorm..."
sudo apt-get update
sudo apt-get install -y \
     git \
     build-essential

git clone https://github.com/umccr/st2-docker-umccr.git /opt/st2-docker-umccr

echo "Preparing for docker-compose"
cd /opt/st2-docker-umccr
# switch to the development branch
git checkout development

cp docker-compose.prod.yml docker-compose.yml


# make env
# # NOTE: we have to initialise with a local setup, as the production environment
# #       is not available. We switch back later for production...
#
# cp docker-compose.local.yml docker-compose.yml
# cat docker-compose.yml
#
# docker pull umccr/stackstorm:latest
# sleep 10
#
# echo "Installing packs..."
# docker-compose up -d
# sleep 10 # otherwise we may get connection errors on stackstorm API side
# echo "Installing Arteria pack..."
# docker-compose exec -T stackstorm st2 pack install https://github.com/umccr/arteria-packs.git
# echo "Installing UMCCR pack..."
# docker-compose exec -T stackstorm st2 pack install https://github.com/umccr/stackstorm-umccr.git
# echo "Installing Ansible pack..."
# docker-compose exec -T stackstorm st2 pack install https://github.com/umccr/stackstorm-ansible.git
# echo "Installing st2 pack..."
# docker-compose exec -T stackstorm st2 pack install https://github.com/StackStorm-Exchange/stackstorm-st2.git
# echo "Installing PCGR pack..."
# docker-compose exec -T stackstorm st2 pack install https://github.com/umccr/stackstorm-pcgr.git
# echo "Finishing up..."
# docker-compose down -v
#
# cp docker-compose.prod.yml docker-compose.yml
