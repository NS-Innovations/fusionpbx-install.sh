#!/bin/sh

# configure.sh - Interactively collect variables and write resources/config.sh
# Drop this file alongside install.sh in the debian/ (or ubuntu/, devuan/, etc.) directory.
# It is sourced/called by install.sh BEFORE resources/config.sh is sourced.
#
# Usage (standalone):   ./configure.sh
# Usage (from install): . ./configure.sh

#move to the directory this script lives in so relative paths work
cd "$(dirname "$0")" 2>/dev/null || true

CONFIG_FILE="./resources/config.sh"

# ---------------------------------------------------------------------------
# Helper: prompt with a default value
#   ask <variable_name> <prompt_text> <default_value>
# ---------------------------------------------------------------------------
ask() {
    _var="$1"
    _prompt="$2"
    _default="$3"

    printf "%s [%s]: " "$_prompt" "$_default"
    read -r _input </dev/tty
    [ -z "$_input" ] && _input="$_default"
    eval "${_var}=\"\${_input}\""
}

# ---------------------------------------------------------------------------
# Helper: silent prompt for passwords/tokens (no echo)
#   ask_secret <variable_name> <prompt_text>
# ---------------------------------------------------------------------------
ask_secret() {
    _var="$1"
    _prompt="$2"

    if stty -echo 2>/dev/null; then
        printf "%s: " "$_prompt"
        read -r _input </dev/tty
        stty echo
        echo ""
    else
        printf "%s (input visible - no tty echo control): " "$_prompt"
        read -r _input </dev/tty
    fi
    eval "${_var}=\"\${_input}\""
}

# ---------------------------------------------------------------------------
# Helper: yes/no prompt normalised to true/false
#   ask_bool <variable_name> <prompt_text> <default true|false>
# ---------------------------------------------------------------------------
ask_bool() {
    _var="$1"
    _prompt="$2"
    _default="$3"

    while true; do
        printf "%s (true/false) [%s]: " "$_prompt" "$_default"
        read -r _input </dev/tty
        [ -z "$_input" ] && _input="$_default"
        case "$_input" in
            true|yes|y|1)  eval "${_var}=true";  break ;;
            false|no|n|0)  eval "${_var}=false"; break ;;
            *) echo "  Please enter true or false." ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Helper: yes/no gate — returns 0 for yes, 1 for no
#   ask_yn <prompt_text> <default y|n>
# ---------------------------------------------------------------------------
ask_yn() {
    _prompt="$1"
    _default="$2"

    while true; do
        printf "%s (y/n) [%s]: " "$_prompt" "$_default"
        read -r _input </dev/tty
        [ -z "$_input" ] && _input="$_default"
        case "$_input" in
            y|Y|yes|YES) return 0 ;;
            n|N|no|NO)   return 1 ;;
            *) echo "  Please enter y or n." ;;
        esac
    done
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
    ask      domain_name         "Domain name (hostname, ip_address, or custom)"  "ip_address"
    ask      system_username     "FusionPBX admin username"                        "admin"
    ask      system_password     "FusionPBX admin password (random = auto)"        "random"
    ask      system_branch       "FusionPBX branch (master, 5.5)"                 "5.5"
    ask      php_version         "PHP version (8.3, 8.2, 8.1)"                    "8.2"
    ask_bool letsencrypt_folder  "Create Let's Encrypt folder structure"           "true"
    echo ""
else
    domain_name=ip_address
    system_username=admin
    system_password=random
    system_branch=5.5
    php_version=8.2
    letsencrypt_folder=true
    echo "  Using defaults for all basic settings."
    echo ""
fi

# ===========================================================================
# SECTION 2 — Advanced Install Settings (optional)
# ===========================================================================
echo "------------------------------------------------------------"
echo " Advanced Install Settings"
echo "------------------------------------------------------------"
if ask_yn "Customize advanced settings (FreeSWITCH, Database, Sofia-Sip)" "n"; then
    echo ""

    # --- FreeSWITCH ---
    echo "  -- FreeSWITCH --"
    ask      switch_branch   "  Branch (master, stable)"                       "stable"
    ask_bool switch_source   "  Compile from source"                           "true"
    ask_bool switch_package  "  Install from binary package"                   "false"
    ask      switch_version  "  Source version (source builds only)"           "1.10.12"
    ask_bool switch_tls      "  Enable TLS"                                    "true"
    ask      switch_token    "  SignalWire auth token (blank if none)"         ""
    echo ""

    # --- Sofia-Sip ---
    echo "  -- Sofia-Sip --"
    ask      sofia_version   "  Release version"                               "1.13.17"
    echo ""

    # --- Database ---
    echo "  -- Database --"
    ask      database_name      "  Database name"                              "fusionpbx"
    ask      database_username  "  Database username"                          "fusionpbx"
    ask      database_password  "  Database password (random = auto)"          "random"
    ask      database_repo      "  PostgreSQL repo (official, system)"         "official"
    ask      database_version   "  PostgreSQL version (requires repo=official)" "18"
    ask      database_host      "  Database host"                              "127.0.0.1"
    ask      database_port      "  Database port"                              "5432"
    ask_bool database_backup    "  Enable database backup"                     "false"
    echo ""
else
    # Apply defaults silently
    switch_branch=stable
    switch_source=true
    switch_package=false
    switch_version=1.10.12
    switch_tls=true
    switch_token=
    sofia_version=1.13.17
    database_name=fusionpbx
    database_username=fusionpbx
    database_password=random
    database_repo=official
    database_version=18
    database_host=127.0.0.1
    database_port=5432
    database_backup=false
    echo "  Using defaults for all advanced settings."
    echo ""
fi

# ===========================================================================
# SECTION 3 — Additional Applications
# ===========================================================================
echo "------------------------------------------------------------"
echo " Additional Applications"
echo "------------------------------------------------------------"
if ask_yn "Customize additional applications" "y"; then
    echo ""
    ask_bool application_transcribe      "Install Speech-to-Text (transcribe)"        "true"
    ask_bool application_speech          "Install Text-to-Speech"                      "true"
    ask_bool application_language_model  "Install Language Model"                      "true"
    ask_bool application_device_logs     "Log device provision requests"               "true"
    ask_bool application_dialplan_tools  "Install additional dialplan applications"    "false"
    ask_bool application_edit            "Install XML/Script/PHP editor"               "false"
    ask_bool application_sip_trunks      "Install registration-based SIP trunks"       "false"
    echo ""
else
    application_transcribe=true
    application_speech=true
    application_language_model=true
    application_device_logs=true
    application_dialplan_tools=false
    application_edit=false
    application_sip_trunks=false
    echo "  Using defaults for all additional applications."
    echo ""
fi

# ===========================================================================
# SECTION 4 — Git Credentials
# ===========================================================================
# Auto-detect server hostname from the clone URL in resources/fusionpbx.sh
_git_server=$(grep 'git clone' ./resources/fusionpbx.sh \
    | grep -o 'https://[^/]*' \
    | sed 's|https://||' \
    | head -1)

_git_credentials_written=false

echo "------------------------------------------------------------"
echo " Git Credentials"
echo "------------------------------------------------------------"
echo " Server detected from resources/fusionpbx.sh: ${_git_server:-<not found>}"
if ask_yn "Configure git credentials" "y"; then
    echo ""
    echo " Credentials will be written immediately to /root/.git-credentials (mode 600)."
    echo " Leave username blank to skip."
    echo ""
    ask _git_username "Git username or email" ""
    if [ -n "$_git_username" ]; then
        ask_secret _git_password "Git password or personal access token"

        # URL-encode characters that would break the credentials file URL format
        _enc_user=$(printf '%s' "$_git_username" | sed \
            -e 's/%/%25/g' -e 's/ /%20/g' \
            -e 's/:/%3A/g' -e 's/@/%40/g')
        _enc_pass=$(printf '%s' "$_git_password" | sed \
            -e 's/%/%25/g' -e 's/ /%20/g' \
            -e 's/:/%3A/g' -e 's/@/%40/g')

        _CREDS_FILE="/root/.git-credentials"

        # Remove any pre-existing entry for this server to avoid duplicates
        if [ -f "$_CREDS_FILE" ]; then
            sed -i "/@${_git_server}/d" "$_CREDS_FILE"
        fi

        printf 'https://%s:%s@%s\n' "$_enc_user" "$_enc_pass" "$_git_server" \
            >> "$_CREDS_FILE"
        chmod 600 "$_CREDS_FILE"

        _git_credentials_written=true
        echo "  Credentials written to $_CREDS_FILE"
    else
        echo "  No username entered — skipping credential store."
    fi

    # Clear sensitive variables immediately
    unset _git_password _enc_pass _git_username _enc_user
    echo ""
else
    echo "  Skipping git credential configuration."
    echo ""
fi

# ===========================================================================
# SUMMARY — read back all settings and ask to confirm
# ===========================================================================
echo "============================================================"
echo " Configuration Summary"
echo "============================================================"
echo ""
echo " Basic Settings"
echo "   domain_name          = $domain_name"
echo "   system_username      = $system_username"
echo "   system_password      = $system_password"
echo "   system_branch        = $system_branch"
echo "   php_version          = $php_version"
echo "   letsencrypt_folder   = $letsencrypt_folder"
echo ""
echo " Advanced Settings (FreeSWITCH / Sofia-Sip / Database)"
echo "   switch_branch        = $switch_branch"
echo "   switch_source        = $switch_source"
echo "   switch_package       = $switch_package"
echo "   switch_version       = $switch_version"
echo "   switch_tls           = $switch_tls"
echo "   switch_token         = ${switch_token:-<not set>}"
echo "   sofia_version        = $sofia_version"
echo "   database_name        = $database_name"
echo "   database_username    = $database_username"
echo "   database_password    = $database_password"
echo "   database_repo        = $database_repo"
echo "   database_version     = $database_version"
echo "   database_host        = $database_host"
echo "   database_port        = $database_port"
echo "   database_backup      = $database_backup"
echo ""
echo " Additional Applications"
echo "   transcribe           = $application_transcribe"
echo "   speech               = $application_speech"
echo "   language_model       = $application_language_model"
echo "   device_logs          = $application_device_logs"
echo "   dialplan_tools       = $application_dialplan_tools"
echo "   edit                 = $application_edit"
echo "   sip_trunks           = $application_sip_trunks"
echo ""
echo " Git Credentials"
echo "   git_server           = ${_git_server:-<not detected>}"
echo "   credentials          = ${_git_credentials_written}"
echo ""
echo "============================================================"
echo ""

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