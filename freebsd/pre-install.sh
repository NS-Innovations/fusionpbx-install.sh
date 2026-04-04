#!/bin/sh

#install git
pkg install --yes git

#get the install script
cd /usr/src && git clone https://git.nsinnovations.net/nsinnovations/fusionpbx-install.sh.git

#change the working directory
cd /usr/src/fusionpbx-install.sh/freebsd/
