#!/bin/bash

# Exit on error
set -e

# Function to print error messages
print_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Function to print status messages
print_status() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to print warning messages
print_warning() {
    echo "[WARNING] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

current_path="$(pwd)"

# Install Go dependencies
bash "$current_path/install-go.sh" || print_error "Failed to install Go dependencies"

# Source bashrc and set ulimit
source "$HOME/.bashrc" || print_error "Failed to source bashrc"
ulimit -n 16384 || print_error "Failed to set ulimit"

print_status "Installing cosmovisor..."
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0 || print_error "Failed to install cosmovisor"

# Get OS and version
OS=$(awk -F '=' '/^NAME/{print $2}' /etc/os-release | awk '{print $1}' | tr -d '"')
VERSION=$(awk -F '=' '/^VERSION_ID/{print $2}' /etc/os-release | awk '{print $1}' | tr -d '"')

# Define the binary and installation paths
BINARY="shidod"
INSTALL_PATH="/usr/local/bin/"

# Check if the OS is Ubuntu and the version is either 20.04 or 22.04
if [ "$OS" = "Ubuntu" ] && { [ "$VERSION" = "20.04" ] || [ "$VERSION" = "22.04" ]; }; then
    print_status "Starting installation for Ubuntu $VERSION..."
    print_status "Binary: $BINARY"
    print_status "Install path: $INSTALL_PATH"
    print_status "Downloading shidod binary for Ubuntu $VERSION..."
    
    # Download the binary
    DOWNLOAD_URL="https://github.com/ShidoGlobal/shido-testnet-terra-upgrade/releases/download/terra-upgrade/shidod"
    print_status "Download URL: $DOWNLOAD_URL"
    
    # Remove existing binary if present
    if [ -f "$BINARY" ]; then
        rm -f "$BINARY"
    fi
    
    # Download with error checking
    if command -v wget >/dev/null 2>&1; then
        wget "$DOWNLOAD_URL" -O "$BINARY"
    elif command -v curl >/dev/null 2>&1; then
        curl -L "$DOWNLOAD_URL" -o "$BINARY"
    else
        print_error "Neither wget nor curl is installed. Please install one of them."
        exit 1
    fi
    
    # Verify download
    if [ ! -f "$BINARY" ]; then
        print_error "Failed to download binary"
        exit 1
    fi
    
    # Make the binary executable
    chmod +x "$BINARY"
    
    # Verify binary works
    if ./"$BINARY" version >/dev/null 2>&1; then
        print_status "Binary downloaded and verified successfully"
    else
        print_warning "Binary downloaded but version check failed"
    fi
  
  current_path=$(pwd)
  
  # Update package lists and install necessary packages
  print_status "Installing system dependencies..."
  sudo apt-get update -y || print_error "Failed to update package lists"
  sudo apt-get install -y build-essential jq wget unzip || print_error "Failed to install dependencies"
  
  # Check if the installation path exists
  if [ -d "$INSTALL_PATH" ]; then
    sudo  cp "$current_path/$BINARY" "$INSTALL_PATH" && sudo chmod +x "${INSTALL_PATH}${BINARY}"
    echo "$BINARY installed or updated successfully!"
  else
    echo "Installation path $INSTALL_PATH does not exist. Please create it."
    exit 1
  fi
else
  echo "Please check the OS version support; at this time, only Ubuntu 20.04 and 22.04 are supported."
  exit 1
fi

print_status "Installing WASMVM library..."

# Remove existing WASMVM library
if [ -f "/usr/lib/libwasmvm.x86_64.so" ]; then
    print_status "Removing existing WASMVM library..."
    sudo rm /usr/lib/libwasmvm.x86_64.so || print_error "Failed to remove existing WASMVM library"
fi

# Download WASMVM library
print_status "Downloading WASMVM library v2.1.4..."
sudo wget -O /usr/lib/libwasmvm.x86_64.so https://github.com/CosmWasm/wasmvm/releases/download/v2.1.4/libwasmvm.x86_64.so \
    || print_error "Failed to download WASMVM library"

# Update library cache
print_status "Updating library cache..."
sudo ldconfig || print_error "Failed to update library cache"

# Verify installation
if [ -f "/usr/lib/libwasmvm.x86_64.so" ]; then
    print_status "WASMVM library installed successfully"
else
    print_error "WASMVM library installation failed"
fi
#==========================================================================================================================================
KEYS="joy"
CHAINID="shido_9007-1"
KEYRING="os"
MONIKER="AlphaValidator"
KEYALGO="eth_secp256k1"
LOGLEVEL="info"

# Set dedicated home directory for the shidod instance
 HOMEDIR="/data/.tmp-shidod"

# Path variables
CONFIG=$HOMEDIR/config/config.toml
APP_TOML=$HOMEDIR/config/app.toml
CLIENT=$HOMEDIR/config/client.toml
GENESIS=$HOMEDIR/config/genesis.json
TMP_GENESIS=$HOMEDIR/config/tmp_genesis.json

# validate dependencies are installed
command -v jq >/dev/null 2>&1 || {
	echo >&2 "jq not installed. More info: https://stedolan.github.io/jq/download/"
	exit 1
}

# used to exit on first error
set -e

# User prompt if an existing local node configuration is found.
if [ -d "$HOMEDIR" ]; then
	printf "\nAn existing folder at '%s' was found. You can choose to delete this folder and start a new local node with new keys from genesis. When declined, the existing local node is started. \n" "$HOMEDIR"
	echo "Overwrite the existing configuration and start a new local node? [y/n]"
	read -r overwrite
else
	overwrite="Y"
fi

# Setup local node if overwrite is set to Yes, otherwise skip setup
if [[ $overwrite == "y" || $overwrite == "Y" ]]; then
	# Remove the previous folder
	file_path="/etc/systemd/system/shidochain.service"

# Check if the file exists
if [ -e "$file_path" ]; then
sudo systemctl stop shidochain.service
    echo "The file $file_path exists."
fi
	sudo rm -rf "$HOMEDIR"

	# Set client config
	shidod config set client chain-id "$CHAINID" --home "$HOMEDIR"
	shidod config set client keyring-backend "$KEYRING" --home "$HOMEDIR"
    echo "===========================Copy these keys with mnemonics and save it in safe place ==================================="
	shidod keys add $KEYS --keyring-backend $KEYRING --algo $KEYALGO --home "$HOMEDIR"
	echo "========================================================================================================================"
	echo "========================================================================================================================"
	shidod init $MONIKER -o --chain-id $CHAINID --home "$HOMEDIR"


	#changes status in app,config files
    sed -i 's/timeout_commit = "3s"/timeout_commit = "500ms"/g' "$CONFIG"
    sed -i 's/pruning = "default"/pruning = "custom"/g' "$APP_TOML"
    sed -i 's/pruning-keep-recent = "0"/pruning-keep-recent = "100000"/g' "$APP_TOML"
    sed -i 's/pruning-interval = "0"/pruning-interval = "100"/g' "$APP_TOML"
    sed -i 's/seeds = ""/seeds = ""/g' "$CONFIG"
    sed -i 's/prometheus = false/prometheus = true/' "$CONFIG"
    sed -i 's/experimental_websocket_write_buffer_size = 200/experimental_websocket_write_buffer_size = 600/' "$CONFIG"
    sed -i 's/prometheus-retention-time  = "0"/prometheus-retention-time  = "1000000000000"/g' "$APP_TOML"
    sed -i 's/enabled = false/enabled = true/g' "$APP_TOML"
    sed -i 's/minimum-gas-prices = "0shido"/minimum-gas-prices = "0.25shido"/g' "$APP_TOML"
    sed -i 's/enable = false/enable = true/g' "$APP_TOML"
    sed -i 's/swagger = false/swagger = true/g' "$APP_TOML"
    sed -i 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/g' "$APP_TOML"
    sed -i 's/enable-unsafe-cors = false/enable-unsafe-cors = true/g' "$APP_TOML"
        sed -i '/\[rosetta\]/,/^\[.*\]/ s/enable = true/enable = false/' "$APP_TOML"
	sed -i 's/localhost/0.0.0.0/g' "$APP_TOML"
    sed -i 's/localhost/0.0.0.0/g' "$CONFIG"
    sed -i 's/:26660/0.0.0.0:26660/g' "$CONFIG"
    sed -i 's/localhost/0.0.0.0/g' "$CLIENT"
    sed -i 's/127.0.0.1/0.0.0.0/g' "$APP_TOML"
    sed -i 's/127.0.0.1/0.0.0.0/g' "$CONFIG"
    sed -i 's/127.0.0.1/0.0.0.0/g' "$CLIENT"
    sed -i 's/\[\]/["*"]/g' "$CONFIG"
	sed -i 's/\["\*",\]/["*"]/g' "$CONFIG"
    # enable prometheus metrics and all APIs for dev node
	if [[ "$OSTYPE" == "darwin"* ]]; then
		sed -i '' 's/prometheus = false/prometheus = true/' "$CONFIG"
		sed -i '' 's/prometheus-retention-time = 0/prometheus-retention-time  = 1000000000000/g' "$APP_TOML"
		sed -i '' 's/enabled = false/enabled = true/g' "$APP_TOML"
		sed -i '' 's/enable = false/enable = true/g' "$APP_TOML"
		# Don't enable Rosetta API by default
		grep -q -F '[rosetta]' "$APP_TOML" && sed -i '' '/\[rosetta\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
		# Don't enable memiavl by default
		grep -q -F '[memiavl]' "$APP_TOML" && sed -i '' '/\[memiavl\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
		# Don't enable versionDB by default
		grep -q -F '[versiondb]' "$APP_TOML" && sed -i '' '/\[versiondb\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
	else
		sed -i 's/prometheus = false/prometheus = true/' "$CONFIG"
		sed -i 's/prometheus-retention-time  = "0"/prometheus-retention-time  = "1000000000000"/g' "$APP_TOML"
		sed -i 's/enabled = false/enabled = true/g' "$APP_TOML"
		sed -i 's/enable = false/enable = true/g' "$APP_TOML"
		# Don't enable Rosetta API by default
		grep -q -F '[rosetta]' "$APP_TOML" && sed -i '/\[rosetta\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
		# Don't enable memiavl by default
		grep -q -F '[memiavl]' "$APP_TOML" && sed -i '/\[memiavl\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
		# Don't enable versionDB by default
		grep -q -F '[versiondb]' "$APP_TOML" && sed -i '/\[versiondb\]/,/^\[/ s/enable = true/enable = false/' "$APP_TOML"
	fi
  
    sed -i 's/flush_throttle_timeout = "100ms"/flush_throttle_timeout = "10ms"/g' "$CONFIG"
    sed -i 's/peer_gossip_sleep_duration = "100ms"/peer_gossip_sleep_duration = "10ms"/g' "$CONFIG"

	# these are some of the node ids help to sync the node with p2p connections
	sed -i 's/persistent_peers \s*=\s* ""/persistent_peers = "3acde7bb97655e37b6d8e3c43af788f67307a727@46.250.173.18:26656,1902cba1e2afb2027c1f882d3ba1f4094920afe9@110.238.81.118:26656,38aa23567af1b8411d887b4b1ec14a72a2decaf3@101.44.185.213:26656,917607ff772fbe2d13ffe8ee03c44bbf18329ab8@46.250.162.115:26656"/g' "$CONFIG"

	# remove the genesis file from binary
	 rm -rf $HOMEDIR/config/genesis.json

	# paste the genesis file
	 cp $current_path/genesis.json $HOMEDIR/config

	# Run this to ensure everything worked and that the genesis file is setup correctly
	# shidod validate-genesis --home "$HOMEDIR"

	echo "export DAEMON_NAME=shidod" >> ~/.profile
    echo "export DAEMON_HOME="$HOMEDIR"" >> ~/.profile
    source ~/.profile
    echo $DAEMON_HOME
    echo $DAEMON_NAME

	cosmovisor init "${INSTALL_PATH}${BINARY}"

	
	TENDERMINTPUBKEY=$(shidod tendermint show-validator --home $HOMEDIR | grep "key" | cut -c12-)
	NodeId=$(shidod tendermint show-node-id --home $HOMEDIR --keyring-backend $KEYRING)
	BECH32ADDRESS=$(shidod keys show ${KEYS} --home $HOMEDIR --keyring-backend $KEYRING| grep "address" | cut -c12-)

	echo "========================================================================================================================"
	echo "tendermint Key==== "$TENDERMINTPUBKEY
	echo "BECH32Address==== "$BECH32ADDRESS
	echo "NodeId ===" $NodeId
	echo "========================================================================================================================"

fi

#========================================================================================================================================================
sudo su -c  "echo '[Unit]
Description=Shido Node
Wants=network-online.target
After=network-online.target
[Service]
User=$(whoami)
Group=$(whoami)
Type=simple
ExecStart=/$(which cosmovisor) run start --home $DAEMON_HOME
Restart=always
RestartSec=3
LimitNOFILE=4096
Environment="DAEMON_NAME=shidod"
Environment="DAEMON_HOME="$HOMEDIR""
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="DAEMON_LOG_BUFFER_SIZE=512"
Environment="UNSAFE_SKIP_BACKUP=false"
[Install]
WantedBy=multi-user.target'> /etc/systemd/system/shidochain.service"

sudo systemctl daemon-reload
sudo systemctl enable shidochain.service
sudo systemctl start shidochain.service
