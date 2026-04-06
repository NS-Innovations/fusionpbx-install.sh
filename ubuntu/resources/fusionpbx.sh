#!/bin/sh

#move to script directory so all relative paths work
cd "$(dirname "$0")"

#includes
. ./config.sh
. ./colors.sh

#send a message
verbose "Installing FusionPBX"

#install dependencies
apt-get install -y vim git dbus haveged ssl-cert qrencode
apt-get install -y ghostscript libtiff5-dev libtiff-tools at

#get the branch
if [ .$system_branch = .'master' ]; then
	verbose "Using master"
	branch=""
else
	system_major=$(git ls-remote --heads https://$GIT_EMAIL:$GIT_PASSWORD@git.nsinnovations.net/nsinnovations/fusionpbx.git| cut -d/ -f 3 | grep -P '^\d+\.\d+' | sort | tail -n 1 | cut -d. -f1)
	system_minor=$(git ls-remote --tags https://$GIT_EMAIL:$GIT_PASSWORD@git.nsinnovations.net/nsinnovations/fusionpbx.git$system_major.* | cut -d/ -f3 |  grep -P '^\d+\.\d+' | sort | tail -n 1 | cut -d. -f2)
	system_version=$system_major.$system_minor
	verbose "Using version $system_version"
	branch="-b $system_version"
fi

#add the cache directory
mkdir -p /var/cache/fusionpbx
chown -R www-data:www-data /var/cache/fusionpbx

#get the source code
git clone $branch https://$GIT_EMAIL:$GIT_PASSWORD@git.nsinnovations.net/nsinnovations/fusionpbx.git/var/www/fusionpbx
chown -R www-data:www-data /var/www/fusionpbx
