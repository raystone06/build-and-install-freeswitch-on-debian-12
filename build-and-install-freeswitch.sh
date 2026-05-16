#!/bin/bash
## Interactive script for building/installing FreeSWITCH from source on Debian 12.
## Original URL: https://gist.github.com/mariogasparoni/dc4490fcc85a527ac45f3d42e35a962c
##
## Enhanced version with:
##   - Interactive prompts for installation path and version
##   - Dedicated freeswitch user/group
##   - Symbolic links to standard Debian paths
##   - Global PATH configuration
##   - systemd service (auto-enable + auto-start)
##
## Author : Laurent Raymond
## GitHub : https://github.com/raystone06
##
## Freely distributed under the MIT license
##
## Run with: sudo bash install-freeswitch.sh

set -e

# ============================================================================
# TERMINAL COLORS
# ============================================================================
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
RESET='\033[0m'

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
print_line() {
    echo -e "${CYAN}================================================================${RESET}"
}

print_banner() {
    clear
    echo ""
    echo -e "${CYAN}================================================================${RESET}"
    echo -e "${CYAN}||${RESET}                                                            ${CYAN}||${RESET}"
    echo -e "${CYAN}||${RESET}   ${BOLD}${WHITE}WELCOME TO THE FREESWITCH BUILD AND INSTALL SCRIPT${RESET}       ${CYAN}||${RESET}"
    echo -e "${CYAN}||${RESET}   ${BOLD}${WHITE}                  ON DEBIAN 12${RESET}                            ${CYAN}||${RESET}"
    echo -e "${CYAN}||${RESET}                                                            ${CYAN}||${RESET}"
    echo -e "${CYAN}================================================================${RESET}"
    echo ""
    echo -e "  ${DIM}Author    :${RESET} ${BOLD}Laurent Raymond${RESET}"
    echo -e "  ${DIM}LinkedIn  :${RESET} ${BLUE}https://www.linkedin.com/in/laurent-raymond-aka/${RESET}"
    echo -e "  ${DIM}GitHub    :${RESET} ${BLUE}https://github.com/raystone06${RESET}"
    echo ""
    print_line
    echo ""
}

print_section() {
    echo ""
    echo -e "${YELLOW}${BOLD}>>> $1${RESET}"
    echo -e "${YELLOW}----------------------------------------------------------------${RESET}"
}

print_info() {
    echo -e "  ${CYAN}[INFO]${RESET} $1"
}

print_success() {
    echo -e "  ${GREEN}[OK]${RESET} $1"
}

print_warning() {
    echo -e "  ${YELLOW}[WARN]${RESET} $1"
}

print_error() {
    echo -e "  ${RED}[ERROR]${RESET} $1"
}

# ============================================================================
# DISPLAY BANNER
# ============================================================================
print_banner

# ============================================================================
# INTERACTIVE CONFIGURATION
# ============================================================================

# ----- Default values -----
DEFAULT_PREFIX="/opt/freeswitch"
DEFAULT_RELEASE="master"
FREESWITCH_SOURCE="https://github.com/signalwire/freeswitch.git"
FS_USER="freeswitch"
FS_GROUP="freeswitch"

# Modules to exclude from the build
REMOVED_MODULES=(
    mod_signalwire
#   mod_pgsql
)

echo -e "${BOLD}Please configure your installation${RESET}"
echo -e "${DIM}(Press ENTER to accept the default value shown in brackets)${RESET}"
echo ""

# ----- Prompt 1: Installation prefix -----
echo -e "${BOLD}1. Installation path${RESET}"
echo ""
echo -e "   This is where FreeSWITCH files will be installed."
echo -e "   Recommended locations (FHS-compliant):"
echo -e "     - ${GREEN}/opt/freeswitch${RESET}        third-party self-contained apps"
echo -e "     - ${GREEN}/srv/freeswitch${RESET}        network services"
echo -e "     - ${GREEN}/usr/local/freeswitch${RESET}  locally compiled software"
echo ""
read -p "   Installation path [${DEFAULT_PREFIX}]: " PREFIX
PREFIX=${PREFIX:-$DEFAULT_PREFIX}
echo ""
print_success "Installation path set to: ${BOLD}${PREFIX}${RESET}"
echo ""

# ----- Prompt 2: FreeSWITCH version -----
echo -e "${BOLD}2. FreeSWITCH version${RESET}"
echo ""
echo -e "   You can install any tag or branch from the official repository."
echo -e "   Browse available versions here:"
echo -e "     ${BLUE}https://github.com/signalwire/freeswitch/tags${RESET}"
echo ""
echo -e "   Common choices:"
echo -e "     - ${GREEN}master${RESET}     development branch (latest features)"
echo -e "     - ${GREEN}v1.10.12${RESET}   latest stable release"
echo -e "     - ${GREEN}v1.10.11${RESET}   previous stable release"
echo ""
read -p "   Version/tag to install [${DEFAULT_RELEASE}]: " FREESWITCH_RELEASE
FREESWITCH_RELEASE=${FREESWITCH_RELEASE:-$DEFAULT_RELEASE}
echo ""
print_success "Version set to: ${BOLD}${FREESWITCH_RELEASE}${RESET}"
echo ""

# ----- Confirmation -----
print_line
echo ""
echo -e "${BOLD}Installation summary${RESET}"
echo ""
echo -e "   Installation path  : ${CYAN}${PREFIX}${RESET}"
echo -e "   FreeSWITCH version : ${CYAN}${FREESWITCH_RELEASE}${RESET}"
echo -e "   Service user       : ${CYAN}${FS_USER}${RESET}"
echo -e "   Service auto-start : ${CYAN}yes${RESET}"
echo ""
print_warning "This will REMOVE any existing FreeSWITCH installation at ${PREFIX}"
print_warning "Expected build time: 30 to 50 minutes depending on hardware"
echo ""
read -p "Proceed with installation? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo ""
    print_error "Installation cancelled by user"
    echo ""
    exit 1
fi

echo ""
print_line
echo ""
print_info "Starting installation..."
echo ""

# From here, exit on error AND trace commands
set -x

# ============================================================================
# 1. CLEANUP PREVIOUS INSTALLATION
# ============================================================================

# Stop the service if it already exists
if systemctl list-unit-files | grep -q freeswitch.service; then
    sudo systemctl stop freeswitch.service || true
    sudo systemctl disable freeswitch.service || true
fi

# Kill any remaining FreeSWITCH process
sudo pkill -9 freeswitch || true
sleep 2

# Remove old installation
sudo rm -rf $PREFIX
rm -rf ~/build-$FREESWITCH_RELEASE

# Remove old symbolic links and config files
sudo rm -f /etc/freeswitch
sudo rm -f /var/log/freeswitch
sudo rm -f /var/lib/freeswitch
sudo rm -f /var/run/freeswitch
sudo rm -f /etc/profile.d/freeswitch.sh
sudo rm -f /etc/systemd/system/freeswitch.service

# ============================================================================
# 2. INSTALL DEPENDENCIES
# ============================================================================
sudo apt-get update && sudo apt-get install -y \
    git-core build-essential python3 python3-dev autoconf automake cmake \
    libtool libncurses5 libncurses5-dev make libjpeg-dev pkg-config \
    zlib1g-dev sqlite3 libsqlite3-dev libpcre3-dev libpcre2-dev libspeex-dev libspeexdsp-dev \
    libedit-dev libldns-dev liblua5.1-0-dev libcurl4-gnutls-dev \
    libapr1-dev yasm libsndfile-dev libopus-dev libtiff-dev \
    libavformat-dev libswscale-dev libpq-dev sudo

# ============================================================================
# 3. BUILD PREPARATION
# ============================================================================
mkdir -p ~/build-$FREESWITCH_RELEASE
cd ~/build-$FREESWITCH_RELEASE

PVERSION=( ${FREESWITCH_RELEASE//./ } )
MIN_VERSION=${PVERSION[1]}
PATCH_VERSION=${PVERSION[2]}

if [[ $FREESWITCH_RELEASE = "master" ]] || [[ $MIN_VERSION -ge 10 && $PATCH_VERSION -ge 3 ]]
then
    echo "VERSION => 1.10.3 - need to build libks2, signalwire-c, spandsp and sofia-sip separately"

    # libks2 - required for mod_verto and signalwire
    git clone https://github.com/signalwire/libks.git
    cd libks
    cmake . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=$PREFIX
    make
    sudo make install
    cd ..

    # signalwire-c - required for mod_signalwire
    git clone https://github.com/signalwire/signalwire-c
    cd signalwire-c
    env PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig cmake . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=$PREFIX
    make
    sudo make install
    cd ..

    # libspandsp
    git clone https://github.com/freeswitch/spandsp.git
    cd spandsp
    git checkout 67d2455efe02e7ff0d897f3fd5636fed4d54549e
    ./bootstrap.sh
    ./configure --prefix=$PREFIX
    make
    sudo make install
    cd ..

    # sofia-sip
    git clone https://github.com/freeswitch/sofia-sip.git
    cd sofia-sip
    ./bootstrap.sh
    ./configure --prefix=$PREFIX
    make
    sudo make install
    cd ..
fi

# ============================================================================
# 4. CLONE AND BUILD FREESWITCH
# ============================================================================
touch .config && sudo chown $USER:$USER .config
if [ ! -d freeswitch ]
then
    git clone $FREESWITCH_SOURCE freeswitch
    cd freeswitch
else
    cd freeswitch
    git fetch origin
fi
git reset --hard $FREESWITCH_RELEASE && git clean -d -x -f

# Disable selected modules from build
for module in "${REMOVED_MODULES[@]}"
do
    sed -i "s|^\([^#].*\)\b${module}\b|#\1${module}|g" build/modules.conf.in
done

./bootstrap.sh

# Configure, build & install
env PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig ./configure --prefix=$PREFIX --disable-libvpx
env C_INCLUDE_PATH=$PREFIX/include make
sudo make install config-vanilla

# Package (backup for potential redeployment)
cd ~/build-$FREESWITCH_RELEASE
tar zcvf freeswitch-$FREESWITCH_RELEASE.tar.gz $PREFIX

# ============================================================================
# 5. POST-INSTALL: DEDICATED USER, SYMLINKS, PATH, SYSTEMD
# ============================================================================

# Disable tracing for the post-install section (cleaner output)
set +x

print_section "POST-INSTALL: system configuration"

# ----- 5.1 Create dedicated user and group -----
if ! getent group $FS_GROUP >/dev/null; then
    sudo groupadd --system $FS_GROUP
    print_success "Group '${FS_GROUP}' created"
else
    print_info "Group '${FS_GROUP}' already exists"
fi

if ! getent passwd $FS_USER >/dev/null; then
    sudo useradd --system \
        --gid $FS_GROUP \
        --home-dir $PREFIX \
        --shell /usr/sbin/nologin \
        --comment "FreeSWITCH service account" \
        $FS_USER
    print_success "User '${FS_USER}' created"
else
    print_info "User '${FS_USER}' already exists"
fi

# ----- 5.2 Create missing directories -----
sudo mkdir -p $PREFIX/var/run/freeswitch
sudo mkdir -p $PREFIX/var/log/freeswitch
sudo mkdir -p $PREFIX/var/lib/freeswitch
print_success "Runtime directories created"

# ----- 5.3 Set correct permissions -----
sudo chown -R $FS_USER:$FS_GROUP $PREFIX
sudo chmod -R u=rwX,g=rX,o= $PREFIX
sudo chmod -R u=rwX,g=rwX,o= $PREFIX/etc/freeswitch
sudo chmod -R u=rwX,g=rwX,o= $PREFIX/var
print_success "Permissions applied to ${PREFIX}"

# ----- 5.4 Symbolic links to standard Debian locations -----
sudo ln -sf $PREFIX/etc/freeswitch       /etc/freeswitch
sudo ln -sf $PREFIX/var/log/freeswitch   /var/log/freeswitch
sudo ln -sf $PREFIX/var/lib/freeswitch   /var/lib/freeswitch
sudo ln -sf $PREFIX/var/run/freeswitch   /var/run/freeswitch
print_success "Symbolic links created"

# ----- 5.5 Global PATH for all users -----
sudo tee /etc/profile.d/freeswitch.sh > /dev/null <<EOF
# FreeSWITCH binaries
export PATH="$PREFIX/bin:\$PATH"
EOF
sudo chmod +x /etc/profile.d/freeswitch.sh
export PATH="$PREFIX/bin:$PATH"
print_success "Global PATH configured"

# ----- 5.6 systemd service -----
sudo tee /etc/systemd/system/freeswitch.service > /dev/null <<EOF
[Unit]
Description=FreeSWITCH Open Source Telephony Platform
Documentation=https://developer.signalwire.com/freeswitch/
Wants=network-online.target
After=network-online.target syslog.target

[Service]
Type=forking
PIDFile=/var/run/freeswitch/freeswitch.pid
Environment="DAEMON_OPTS=-nonat"
EnvironmentFile=-/etc/default/freeswitch
ExecStartPre=/bin/mkdir -p /var/run/freeswitch
ExecStartPre=/bin/chown -R $FS_USER:$FS_GROUP /var/run/freeswitch
ExecStart=$PREFIX/bin/freeswitch -ncwait -nonat -u $FS_USER -g $FS_GROUP \$DAEMON_OPTS
ExecReload=$PREFIX/bin/fs_cli -x reload
TimeoutStartSec=45
TimeoutStopSec=45
Restart=on-failure
RestartSec=5

# Security hardening
User=$FS_USER
Group=$FS_GROUP
LimitCORE=infinity
LimitNOFILE=999999
LimitNPROC=60000
LimitSTACK=240
LimitRTPRIO=infinity
LimitRTTIME=7000000
IOSchedulingClass=realtime
IOSchedulingPriority=2
CPUSchedulingPolicy=rr
CPUSchedulingPriority=89

# Isolation
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

# Optional environment file
sudo tee /etc/default/freeswitch > /dev/null <<'EOF'
# Options passed to the FreeSWITCH daemon at startup
# -nonat : disable automatic NAT detection
# -nf    : do not fork
# -hp    : high priority
DAEMON_OPTS="-nonat"
EOF
print_success "systemd service installed"

# ----- 5.7 Enable and start the service -----
sudo systemctl daemon-reload
sudo systemctl enable freeswitch.service
sudo systemctl start freeswitch.service
print_success "Service enabled and started"

# Wait for startup
sleep 5

# ----- 5.8 Final verification -----
print_section "FINAL VERIFICATION"
sudo systemctl status freeswitch.service --no-pager || true

# ============================================================================
# FINAL SUMMARY
# ============================================================================
echo ""
echo ""
echo -e "${GREEN}================================================================${RESET}"
echo -e "${GREEN}||${RESET}                                                            ${GREEN}||${RESET}"
echo -e "${GREEN}||${RESET}            ${BOLD}${WHITE}INSTALLATION COMPLETED SUCCESSFULLY${RESET}             ${GREEN}||${RESET}"
echo -e "${GREEN}||${RESET}                                                            ${GREEN}||${RESET}"
echo -e "${GREEN}================================================================${RESET}"
echo ""
echo -e "  ${BOLD}Installed version${RESET}"
echo -e "  ${DIM}-----------------${RESET}"
$PREFIX/bin/freeswitch -version 2>&1 | sed 's/^/    /'
echo ""
echo -e "  ${BOLD}Installation paths${RESET}"
echo -e "  ${DIM}------------------${RESET}"
echo -e "    Root directory     : ${CYAN}${PREFIX}${RESET}"
echo -e "    Configuration      : ${CYAN}/etc/freeswitch${RESET}        ${DIM}-> ${PREFIX}/etc/freeswitch${RESET}"
echo -e "    Logs               : ${CYAN}/var/log/freeswitch${RESET}    ${DIM}-> ${PREFIX}/var/log/freeswitch${RESET}"
echo -e "    Data               : ${CYAN}/var/lib/freeswitch${RESET}    ${DIM}-> ${PREFIX}/var/lib/freeswitch${RESET}"
echo -e "    Runtime            : ${CYAN}/var/run/freeswitch${RESET}    ${DIM}-> ${PREFIX}/var/run/freeswitch${RESET}"
echo ""
echo -e "  ${BOLD}Service${RESET}"
echo -e "  ${DIM}-------${RESET}"
echo -e "    Service user       : ${CYAN}${FS_USER}${RESET}"
echo -e "    Auto-start at boot : ${CYAN}enabled${RESET}"
echo ""
echo -e "  ${BOLD}Useful commands${RESET}"
echo -e "  ${DIM}---------------${RESET}"
echo -e "    Service status     : ${YELLOW}sudo systemctl status freeswitch${RESET}"
echo -e "    Live logs          : ${YELLOW}sudo journalctl -u freeswitch -f${RESET}"
echo -e "    fs_cli console     : ${YELLOW}sudo fs_cli${RESET}"
echo -e "    Restart            : ${YELLOW}sudo systemctl restart freeswitch${RESET}"
echo -e "    Stop               : ${YELLOW}sudo systemctl stop freeswitch${RESET}"
echo ""
echo -e "  ${YELLOW}NOTE:${RESET} Open a new shell to load the updated PATH,"
echo -e "        or run: ${YELLOW}source /etc/profile.d/freeswitch.sh${RESET}"
echo ""
print_line
echo ""
echo -e "  ${BOLD}${WHITE}Thank you for using this script!${RESET}"
echo ""
echo -e "  If you have a project, a question, or just want to chat,"
echo -e "  feel free to reach out. I would love to hear from you."
echo ""
echo -e "  ${DIM}Author    :${RESET} ${BOLD}Laurent Raymond${RESET}"
echo -e "  ${DIM}LinkedIn  :${RESET} ${BLUE}https://www.linkedin.com/in/laurent-raymond-aka/${RESET}"
echo -e "  ${DIM}GitHub    :${RESET} ${BLUE}https://github.com/raystone06${RESET}"
echo ""
echo -e "  ${RED}<3${RESET}  Made with passion in Abidjan, Cote d'Ivoire"
echo ""
print_line
echo ""
