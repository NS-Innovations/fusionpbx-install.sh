#!/bin/sh

# configure.sh - Interactively collect variables and write resources/config.sh
# Drop this file alongside install.sh in the debian/ (or ubuntu/, devuan/, etc.) directory.
# It is sourced/called by install.sh BEFORE resources/config.sh is sourced.
#
# Usage (standalone):   ./configure.sh
# Usage (from install): . ./configure.sh

cd "$(dirname "$0")" 2>/dev/null || true

CONFIG_FILE="./resources/config.sh"
_CREDS_FILE="/root/.git-credentials"

# ===========================================================================
# Defaults — every variable is pre-populated so sections with no
# customization need no else branch at all.
# ===========================================================================
domain_name=ip_address          ;  system_username=admin
system_password=random          ;  system_branch=5.5
php_version=8.2                 ;  letsencrypt_folder=true
switch_branch=stable            ;  switch_source=true
switch_package=false            ;  switch_version=1.10.12
switch_tls=true                 ;  switch_token=
sofia_version=1.13.17
database_name=fusionpbx         ;  database_username=fusionpbx
database_password=random        ;  database_repo=official
database_version=18             ;  database_host=127.0.0.1
database_port=5432              ;  database_backup=false
application_transcribe=true     ;  application_speech=true
application_language_model=true ;  application_device_logs=true
application_dialplan_tools=false;  application_edit=false
application_sip_trunks=false
_git_credentials_written=false

# ===========================================================================
# Helpers
# ===========================================================================

# ask <var> <prompt> <default>
ask() {
    printf "%s [%s]: " "$2" "$3"
    read -r _input </dev/tty
    eval "${1}=\"${_input:-$3}\""
}

# ask_secret <var> <prompt>  —  no echo
ask_secret() {
    if stty -echo 2>/dev/null; then
        printf "%s: " "$2"
        read -r _input </dev/tty
        stty echo; echo ""
    else
        printf "%s (input visible): " "$2"
        read -r _input </dev/tty
    fi
    eval "${1}=\"${_input}\""
}

# ask_yn <prompt> <default y|n>  —  returns 0=yes 1=no
ask_yn() {
    while true; do
        printf "%s (y/n) [%s]: " "$1" "$2"
        read -r _input </dev/tty
        case "${_input:-$2}" in
            y|Y|yes|YES) return 0 ;;
            n|N|no|NO)   return 1 ;;
            *) echo "  Please enter y or n." ;;
        esac
    done
}

# ask_bool <var> <prompt> <default true|false>  —  wraps ask_yn
ask_bool() {
    _yn=$([ "$3" = "true" ] && echo "y" || echo "n")
    if ask_yn "$2" "$_yn"; then eval "${1}=true"
    else                        eval "${1}=false"
    fi
}

# write_git_credentials <server>
write_git_credentials() {
    _srv="$1"
    ask    _git_username "Git username or email" ""
    [ -z "$_git_username" ] && { echo "  No username entered — skipping."; return; }
    ask_secret _git_password "Git password or personal access token"

    # URL-encode characters that break the credentials file URL format
    _enc_u=$(printf '%s' "$_git_username" | sed 's/%/%25/g;s/ /%20/g;s/:/%3A/g;s/@/%40/g')
    _enc_p=$(printf '%s' "$_git_password" | sed 's/%/%25/g;s/ /%20/g;s/:/%3A/g;s/@/%40/g')

    # Remove any pre-existing entry for this server, then append
    [ -f "$_CREDS_FILE" ] && sed -i "/@${_srv}/d" "$_CREDS_FILE"
    printf 'https://%s:%s@%s\n' "$_enc_u" "$_enc_p" "$_srv" >> "$_CREDS_FILE"
    chmod 600 "$_CREDS_FILE"

    _git_credentials_written=true
    echo "  Credentials written to $_CREDS_FILE"
    unset _git_password _enc_p _git_username _enc_u
}

# ===========================================================================
echo ""
echo "============================================================"
echo " FusionPBX Installer - Configuration Setup"
echo " Values will be written to: $CONFIG_FILE"
echo " Press ENTER to accept the default shown in [brackets]."
echo "============================================================"
echo ""

# ===========================================================================
# SECTION 1 — Basic Settings
# ===========================================================================
echo "------------------------------------------------------------"
echo " Basic Settings"
echo "------------------------------------------------------------"
if ask_yn "Customize basic settings" "y"; then
    echo ""
    ask      domain_name        "Domain name (hostname, ip_address, or custom)" "ip_address"
    ask      system_username    "FusionPBX admin username"                       "admin"
    ask      system_password    "FusionPBX admin password (random = auto)"       "random"
    ask      system_branch      "FusionPBX branch (master, 5.5)"                "5.5"
    ask      php_version        "PHP version (8.3, 8.2, 8.1)"                   "8.2"
    ask_bool letsencrypt_folder "Create Let's Encrypt folder structure"          "true"
    echo ""
else
    echo "  Using defaults."; echo ""
fi

# ===========================================================================
# SECTION 2 — Advanced Install Settings
# ===========================================================================
echo "------------------------------------------------------------"
echo " Advanced Install Settings (FreeSWITCH / Sofia-Sip / Database)"
echo "------------------------------------------------------------"
if ask_yn "Customize advanced settings" "n"; then
    echo ""
    echo "  -- FreeSWITCH --"
    ask      switch_branch  "  Branch (master, stable)"                    "stable"
    ask_bool switch_source  "  Compile from source"                        "true"
    ask_bool switch_package "  Install from binary package"                "false"
    ask      switch_version "  Source version (source builds only)"        "1.10.12"
    ask_bool switch_tls     "  Enable TLS"                                 "true"
    ask      switch_token   "  SignalWire auth token (blank if none)"      ""
    echo ""
    echo "  -- Sofia-Sip --"
    ask      sofia_version  "  Release version"                            "1.13.17"
    echo ""
    echo "  -- Database --"
    ask      database_name      "  Database name"                          "fusionpbx"
    ask      database_username  "  Database username"                      "fusionpbx"
    ask      database_password  "  Database password (random = auto)"      "random"
    ask      database_repo      "  PostgreSQL repo (official, system)"     "official"
    ask      database_version   "  PostgreSQL version"                     "18"
    ask      database_host      "  Database host"                          "127.0.0.1"
    ask      database_port      "  Database port"                          "5432"
    ask_bool database_backup    "  Enable database backup"                 "false"
    echo ""
else
    echo "  Using defaults."; echo ""
fi

# ===========================================================================
# SECTION 3 — Additional Applications
# ===========================================================================
echo "------------------------------------------------------------"
echo " Additional Applications"
echo "------------------------------------------------------------"
if ask_yn "Customize additional applications" "y"; then
    echo ""
    ask_bool application_transcribe     "Install Speech-to-Text (transcribe)"       "true"
    ask_bool application_speech         "Install Text-to-Speech"                     "true"
    ask_bool application_language_model "Install Language Model"                     "true"
    ask_bool application_device_logs    "Log device provision requests"              "true"
    ask_bool application_dialplan_tools "Install additional dialplan applications"   "false"
    ask_bool application_edit           "Install XML/Script/PHP editor"              "false"
    ask_bool application_sip_trunks     "Install registration-based SIP trunks"      "false"
    echo ""
else
    echo "  Using defaults."; echo ""
fi

# ===========================================================================
# SECTION 4 — Git Credentials
# ===========================================================================
_git_server=$(grep 'git clone' ./resources/fusionpbx.sh \
    | grep -o 'https://[^/]*' | sed 's|https://||' | head -1)

echo "------------------------------------------------------------"
echo " Git Credentials"
echo "------------------------------------------------------------"
echo " Server detected: ${_git_server:-<not found>}"
if ask_yn "Configure git credentials" "y"; then
    echo ""
    write_git_credentials "$_git_server"
    echo ""
else
    echo "  Skipping."; echo ""
fi

# ===========================================================================
# SUMMARY
# ===========================================================================
cat <<EOF
============================================================
 Configuration Summary
============================================================

 Basic Settings
   domain_name          = $domain_name
   system_username      = $system_username
   system_password      = $system_password
   system_branch        = $system_branch
   php_version          = $php_version
   letsencrypt_folder   = $letsencrypt_folder

 Advanced Settings (FreeSWITCH / Sofia-Sip / Database)
   switch_branch        = $switch_branch
   switch_source        = $switch_source
   switch_package       = $switch_package
   switch_version       = $switch_version
   switch_tls           = $switch_tls
   switch_token         = ${switch_token:-<not set>}
   sofia_version        = $sofia_version
   database_name        = $database_name
   database_username    = $database_username
   database_password    = $database_password
   database_repo        = $database_repo
   database_version     = $database_version
   database_host        = $database_host
   database_port        = $database_port
   database_backup      = $database_backup

 Additional Applications
   transcribe           = $application_transcribe
   speech               = $application_speech
   language_model       = $application_language_model
   device_logs          = $application_device_logs
   dialplan_tools       = $application_dialplan_tools
   edit                 = $application_edit
   sip_trunks           = $application_sip_trunks

 Git Credentials
   git_server           = ${_git_server:-<not detected>}
   credentials written  = $_git_credentials_written

============================================================
EOF

if ! ask_yn "Continue with installation using these settings" "y"; then
    echo ""
    echo "Installation cancelled. No changes have been made."
    echo ""
    exit 1
fi

echo ""

# ===========================================================================
# Write config.sh
# ===========================================================================
cat > "$CONFIG_FILE" <<EOF
#!/bin/sh

# FusionPBX Settings
domain_name=${domain_name}          # hostname, ip_address or a custom value
system_username=${system_username}  # default username admin
system_password=${system_password}  # random or a custom value
system_branch=${system_branch}      # master, 5.5

# FreeSWITCH Settings
switch_branch=${switch_branch}      # master, stable
switch_source=${switch_source}      # true (source compile) or false (binary package)
switch_package=${switch_package}    # true (binary package) or false (source compile)
switch_version=${switch_version}    # which source code to download, only for source
switch_tls=${switch_tls}            # true or false
switch_token=${switch_token}        # Get the auth token from https://signalwire.com
                                    # Signup or Login -> Profile -> Personal Auth Token

# Sofia-Sip Settings
sofia_version=${sofia_version}      # release-version for sofia-sip to use

# Database Settings
database_name=${database_name}          # Database name (safe characters A-Z, a-z, 0-9)
database_username=${database_username}  # Database username (safe characters A-Z, a-z, 0-9)
database_password=${database_password}  # random or a custom value (safe characters A-Z, a-z, 0-9)
database_repo=${database_repo}          # PostgreSQL official, system
database_version=${database_version}    # requires repo official
database_host=${database_host}          # hostname or IP address
database_port=${database_port}          # port number
database_backup=${database_backup}      # true or false

# General Settings
php_version=${php_version}               # PHP version 8.3, 8.2, 8.1
letsencrypt_folder=${letsencrypt_folder} # true or false

# Optional Applications
application_transcribe=${application_transcribe}         # Speech to Text
application_speech=${application_speech}                 # Text to Speech
application_language_model=${application_language_model} # Language model
application_device_logs=${application_device_logs}       # Log device provision requests
application_dialplan_tools=${application_dialplan_tools} # Add additional dialplan applications
application_edit=${application_edit}                     # Editor for XML, Provision, Scripts, and PHP
application_sip_trunks=${application_sip_trunks}         # Registration-based SIP trunks
EOF

chmod 600 "$CONFIG_FILE"

echo "============================================================"
echo " Configuration saved to: $CONFIG_FILE"
echo "============================================================"
echo ""