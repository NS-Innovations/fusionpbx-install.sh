#!/bin/sh

# configure.sh - Interactively collect variables and write resources/config.sh
# Drop this file alongside install.sh in the debian/ (or ubuntu/, devuan/, etc.) directory.
# It is sourced/called by install.sh BEFORE resources/config.sh is sourced.
#
# Usage (standalone):   ./configure.sh
# Usage (from install): source ./configure.sh   OR   . ./configure.sh

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
    if [ -z "$_input" ]; then
        _input="$_default"
    fi
    # Assign to the named variable in the current shell
    eval "${_var}=\"\${_input}\""
}

# ---------------------------------------------------------------------------
# Helper: silent prompt for passwords/tokens (no echo)
#   ask_secret <variable_name> <prompt_text>
# ---------------------------------------------------------------------------
ask_secret() {
    _var="$1"
    _prompt="$2"

    # stty may not be available in all minimal environments; fall back gracefully
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
# Helper: yes/no prompt that normalises input to true/false
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
            true|yes|y|1)   eval "${_var}=true";  break ;;
            false|no|n|0)   eval "${_var}=false"; break ;;
            *) echo "  Please enter true or false." ;;
        esac
    done
}

# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " FusionPBX Installer - Configuration Setup"
echo " Values will be written to: $CONFIG_FILE"
echo " Press ENTER to accept the default shown in [brackets]."
echo "============================================================"
echo ""

# --- FusionPBX Settings ---
echo "--- FusionPBX Settings ---"
ask      domain_name      "Domain name (hostname, ip_address, or custom)" "ip_address"
ask      system_username  "Admin username"                                 "admin"
ask      system_password  "Admin password (random = auto-generate)"        "random"
ask      system_branch    "FusionPBX branch (master, 5.5)"                 "5.5"
echo ""

# --- FreeSWITCH Settings ---
echo "--- FreeSWITCH Settings ---"
ask      switch_branch    "FreeSWITCH branch (master, stable)"             "stable"
ask_bool switch_source    "Compile FreeSWITCH from source"                 "true"
ask_bool switch_package   "Install FreeSWITCH from binary package"         "false"
ask      switch_version   "FreeSWITCH source version (source builds only)" "1.10.12"
ask_bool switch_tls       "Enable TLS for FreeSWITCH"                      "true"
ask      switch_token     "SignalWire auth token (leave blank if none)"     ""
echo ""

# --- Sofia-Sip Settings ---
echo "--- Sofia-Sip Settings ---"
ask      sofia_version    "Sofia-Sip release version"                      "1.13.17"
echo ""

# --- Database Settings ---
echo "--- Database Settings ---"
ask      database_name     "Database name"                                  "fusionpbx"
ask      database_username "Database username"                              "fusionpbx"
ask      database_password "Database password (random = auto-generate)"     "random"
ask      database_repo     "PostgreSQL repo (official, system)"             "official"
ask      database_version  "PostgreSQL version (requires repo=official)"    "18"
ask      database_host     "Database host"                                  "127.0.0.1"
ask      database_port     "Database port"                                  "5432"
ask_bool database_backup   "Enable database backup"                         "false"
echo ""

# --- General Settings ---
echo "--- General Settings ---"
ask      php_version         "PHP version (8.3, 8.2, 8.1)"                 "8.2"
ask_bool letsencrypt_folder  "Create Let's Encrypt folder structure"        "true"
echo ""

# --- Optional Applications ---
echo "--- Optional Applications ---"
ask_bool application_transcribe      "Install Speech-to-Text (transcribe)"          "true"
ask_bool application_speech          "Install Text-to-Speech"                        "true"
ask_bool application_language_model  "Install Language Model application"            "true"
ask_bool application_device_logs     "Log device provision requests"                 "true"
ask_bool application_dialplan_tools  "Install additional dialplan applications"       "false"
ask_bool application_edit            "Install XML/Script/PHP editor"                 "false"
ask_bool application_sip_trunks      "Install registration-based SIP trunks"         "false"
echo ""

# --- Git Credentials ---
# Parse the git server hostname directly from the clone URL in resources/fusionpbx.sh
# so the user never has to type it and it stays in sync automatically.
git_server=$(grep 'git clone' ./resources/fusionpbx.sh \
    | grep -o 'https://[^/]*' \
    | sed 's|https://||' \
    | head -1)

echo "--- Git Credentials ---"
echo " Server detected from resources/fusionpbx.sh: ${git_server:-<not found>}"
echo " Credentials will be stored in /root/.git-credentials (mode 600)."
echo " Leave username blank to skip credential store configuration."
echo ""
ask        git_username  "Git username or email"               ""
if [ -n "$git_username" ]; then
    ask_secret git_password "Git password or personal access token"
else
    git_password=""
fi
echo ""

# ---------------------------------------------------------------------------
# Write config.sh
# ---------------------------------------------------------------------------
cat > "$CONFIG_FILE" <<EOF
#!/bin/sh

# FusionPBX Settings
domain_name=${domain_name}       # hostname, ip_address or a custom value
system_username=${system_username}  # default username admin
system_password=${system_password}  # random or a custom value
system_branch=${system_branch}     # master, 5.5

# FreeSWITCH Settings
switch_branch=${switch_branch}     # master, stable
switch_source=${switch_source}     # true (source compile) or false (binary package)
switch_package=${switch_package}   # true (binary package) or false (source compile)
switch_version=${switch_version}   # which source code to download, only for source
switch_tls=${switch_tls}        # true or false
switch_token=${switch_token}      # Get the auth token from https://signalwire.com
                                  # Signup or Login -> Profile -> Personal Auth Token

# Sofia-Sip Settings
sofia_version=${sofia_version}    # release-version for sofia-sip to use

# Database Settings
database_name=${database_name}     # Database name (safe characters A-Z, a-z, 0-9)
database_username=${database_username} # Database username (safe characters A-Z, a-z, 0-9)
database_password=${database_password} # random or a custom value (safe characters A-Z, a-z, 0-9)
database_repo=${database_repo}     # PostgreSQL official, system
database_version=${database_version}  # requires repo official
database_host=${database_host}     # hostname or IP address
database_port=${database_port}     # port number
database_backup=${database_backup}   # true or false

# General Settings
php_version=${php_version}        # PHP version 8.3, 8.2, 8.1
letsencrypt_folder=${letsencrypt_folder} # true or false

# Optional Applications
application_transcribe=${application_transcribe}     # Speech to Text
application_speech=${application_speech}          # Text to Speech
application_language_model=${application_language_model}  # Language model
application_device_logs=${application_device_logs}     # Log device provision requests
application_dialplan_tools=${application_dialplan_tools}  # Add additional dialplan applications
application_edit=${application_edit}            # Editor for XML, Provision, Scripts, and PHP
application_sip_trunks=${application_sip_trunks}      # Registration-based SIP trunks

# Git Settings
git_server=${git_server}        # Hostname parsed from resources/fusionpbx.sh clone URL
git_username=${git_username}      # Git username or email for credential store
git_password=${git_password}      # Git password or personal access token
EOF

# Protect config.sh since it now contains credentials
chmod 600 "$CONFIG_FILE"

echo "============================================================"
echo " Configuration saved to: $CONFIG_FILE"
echo "============================================================"
echo ""