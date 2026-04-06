#!/bin/sh

# git.sh - Configure global git settings for the installer
#   - Credential helper pointing to the file-based store
#   - ~/.git-credentials entry for the internal git server
#     (server hostname is read from git_server in config.sh, which is
#      auto-parsed from the clone URL in resources/fusionpbx.sh)
#   - safe.directory for /var/www/fusionpbx (needed when git runs
#     as root but the directory is owned by www-data)
#
# This script must be called AFTER resources/config.sh has been sourced
# so that git_* variables are available.

#move to script directory so all relative paths work
cd "$(dirname "$0")"

#includes
. ./config.sh
. ./colors.sh

verbose "Configuring global git settings"

CREDENTIALS_FILE="/root/.git-credentials"

# ---------------------------------------------------------------------------
# 1. Credential store
# ---------------------------------------------------------------------------
if [ -n "$git_username" ] && [ -n "$git_password" ] && [ -n "$git_server" ]; then

    # Point git at the file-based credential store
    git config --global credential.helper "store --file $CREDENTIALS_FILE"
    verbose "  credential.helper = store --file $CREDENTIALS_FILE"

    # Build the credential URL: https://user:pass@server
    # URL-encode only the characters that would break the URL inside the
    # credentials file (@, :, /, space).  For most tokens/passwords this
    # is sufficient; complex passwords with other special chars should use
    # a personal access token instead.
    _encoded_user=$(printf '%s' "$git_username" | sed \
        -e 's/%/%25/g' \
        -e 's/ /%20/g' \
        -e 's/:/%3A/g' \
        -e 's/@/%40/g')
    _encoded_pass=$(printf '%s' "$git_password" | sed \
        -e 's/%/%25/g' \
        -e 's/ /%20/g' \
        -e 's/:/%3A/g' \
        -e 's/@/%40/g')

    _cred_entry="https://${_encoded_user}:${_encoded_pass}@${git_server}"

    # Write (or replace) the entry for this server in the credentials file.
    # Remove any pre-existing line for the same server first to avoid duplicates.
    if [ -f "$CREDENTIALS_FILE" ]; then
        # Strip existing entries for this server
        sed -i "/@${git_server}/d" "$CREDENTIALS_FILE"
    fi

    printf '%s\n' "$_cred_entry" >> "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"

    verbose "  credentials written to $CREDENTIALS_FILE"

    # Clear sensitive variables from the environment as soon as they are
    # no longer needed.
    unset _encoded_pass _cred_entry

else
    verbose "  git credentials not configured (git_username or git_password not set)"
fi

# ---------------------------------------------------------------------------
# 2. Safe directory for /var/www/fusionpbx
#    Git ≥ 2.35.2 refuses to operate on directories owned by a different
#    user.  The installer runs as root but chowns the checkout to www-data,
#    so subsequent git operations (updates, pulls) fail unless the directory
#    is explicitly marked safe.
# ---------------------------------------------------------------------------
git config --global --add safe.directory /var/www/fusionpbx
verbose "  safe.directory += /var/www/fusionpbx"

verbose "Git configuration complete"