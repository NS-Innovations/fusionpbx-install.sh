#!/bin/sh

# git.sh - Apply global git configuration required by the installer
#   - credential.helper pointing to /root/.git-credentials
#     (the file itself is written by configure.sh before install begins)
#   - safe.directory for /var/www/fusionpbx (needed when git runs as root
#     but the directory is owned by www-data, git >= 2.35.2 requirement)
#
# This script must be called after git is installed (handled by install.sh).

#move to script directory so all relative paths work
cd "$(dirname "$0")"

#includes
. ./config.sh
. ./colors.sh

verbose "Configuring global git settings"

CREDENTIALS_FILE="/root/.git-credentials"

# ---------------------------------------------------------------------------
# 1. Credential helper
#    Wire git to the file-based store that configure.sh already populated.
# ---------------------------------------------------------------------------
git config --global credential.helper "store --file $CREDENTIALS_FILE"
verbose "  credential.helper = store --file $CREDENTIALS_FILE"

# ---------------------------------------------------------------------------
# 2. Safe directory for /var/www/fusionpbx
#    Git >= 2.35.2 refuses to operate on directories owned by a different
#    user. The installer runs as root but chowns the checkout to www-data,
#    so subsequent git operations (updates, pulls) fail without this.
# ---------------------------------------------------------------------------
git config --global --add safe.directory /var/www/fusionpbx
verbose "  safe.directory += /var/www/fusionpbx"

verbose "Git configuration complete"