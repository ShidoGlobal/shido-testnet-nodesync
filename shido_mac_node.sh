#!/bin/bash
current_path=$(pwd)
bash  $current_path/install-go.sh 
bash install-go.sh
bash install-brew.sh
source ~/.zshrc
ulimit -n 46384

# Get OS and version
OS="$(uname -s)"
ARCH="$(uname -m)"
OS_VERSION=$(sw_vers -productVersion)
BUILD_VERSION=$(sw_vers -buildVersion)
echo "macOS version: $OS_VERSION (Build $BUILD_VERSION)"

# Define the binary and installation paths
BINARY="shidod"
INSTALL_PATH="$HOME/go/bin/"

# Check if the OS is Ubuntu and the version is either 20.04 or 22.04
if [ "$OS" == "Darwin" ]; then
  current_path=$(pwd)
  # Update package lists and install necessary packages
  # brew update
  echo "Checking brew"
  brew install jq wget
  
  # Check if the installation path exists
  if [ -d "$INSTALL_PATH" ]; then
  sudo cp "$current_path/macOSVentura13build/$BINARY" "$INSTALL_PATH" && sudo chmod +x "${INSTALL_PATH}${BINARY}"
    echo "$BINARY installed or updated successfully!"
  else
    echo "Installation path $INSTALL_PATH does not exist. Please create it."
    exit 1
  fi
  else
  echo "Please check the OS version support; at this time, only mac ventura 13 are supported."
  exit 1
  fi
  sudo cp $current_path/libwasmvm.dylib /usr/lib
wget https://testnet-blockchain-shido.s3.us-west-2.amazonaws.com/snapshot15apr2024.zip
#==========================================================================================================================================

KEYS="alice"
CHAINID="shido_9007-1"
MONIKER="CosmoGalaxy"
KEYRING="test"
KEYALGO="eth_secp256k1"
LOGLEVEL="info"
# Set dedicated home directory for the streakkd instance
HOMEDIR="$HOME/.tmp-shidod"

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
	sudo rm -rf "$HOMEDIR"
  current_path=$(pwd)

	# Set client config
	shidod config keyring-backend $KEYRING --home "$HOMEDIR"
	shidod config chain-id $CHAINID --home "$HOMEDIR"
  echo "===========================Copy these keys with mnemonics aand save it in safe place ==================================="
	shidod keys add $KEYS --keyring-backend $KEYRING --algo $KEYALGO --home "$HOMEDIR"
  echo "========================================================================================================================"
	echo "========================================================================================================================"
	shidod init $MONIKER -o --chain-id $CHAINID --home "$HOMEDIR"

	#changes status in app,config files
        sed -i '' 's/timeout_commit = "3s"/timeout_commit = "1s"/g' "$CONFIG"
        sed -i '' 's/seeds = ""/seeds = ""/g' "$CONFIG"
        sed -i '' 's/prometheus = false/prometheus = true/' "$CONFIG"
        sed -i '' 's/prometheus-retention-time  = "0"/prometheus-retention-time  = "1000000000000"/g' "$APP_TOML"
        sed -i '' 's/enabled = false/enabled = true/g' "$APP_TOML"
        sed -i '' 's/enable = false/enable = true/g' "$APP_TOML"
        sed -i '' 's/swagger = false/swagger = true/g' "$APP_TOML"
        sed -i '' 's/enabled-unsafe-cors = false/enabled-unsafe-cors = true/g' "$APP_TOML"

	      sed -i '' 's/localhost/0.0.0.0/g' "$APP_TOML"
        sed -i '' 's/localhost/0.0.0.0/g' "$CONFIG"
        sed -i '' 's/localhost/0.0.0.0/g' "$CLIENT"
        sed -i '' 's/127.0.0.1/0.0.0.0/g' "$APP_TOML"
        sed -i '' 's/127.0.0.1/0.0.0.0/g' "$CONFIG"
        sed -i '' 's/127.0.0.1/0.0.0.0/g' "$CLIENT"
        sed -i '' 's/\[\]/["*"]/g' "$CONFIG"
	      sed -i '' 's/\["\*",\]/["*"]/g' "$CONFIG"
        sed -i '' 's/127.0.0.1/0.0.0.0/g' "$CLIENT"


	# these are some of the node ids help to sync the node with p2p connections
	sed -i '' 's/persistent_peers \s*=\s* ""/persistent_peers = "7248e4bc6936f39090e4b9a0b50122abd5adc965@35.82.44.23:26656,518d20eff4c02cfd9a7a31b06df4f89f813594e0@100.21.69.117:25556,2333b40fe2a6c290cd187bc8e6ea6dc19ec0e9b6@44.236.180.179:26656,7bd130ba4991664d19fc7cfeb00d6a3cbcc8eed0@44.227.80.206:26656"/g' "$CONFIG"

	# remove the genesis file from binary
	rm -rf $HOMEDIR/config/genesis.json

	# paste the genesis file 
	cp $current_path/genesis.json $HOMEDIR/config

  cd $HOMEDIR/data
	unzip	$current_path/snapshot15apr2024.zip
	# Run this to ensure everything worked and that the genesis file is setup correctly
	shidod validate-genesis --home "$HOMEDIR"

  ADDRESS=$(shidod keys list --home $HOMEDIR --keyring-backend $KEYRING | grep "address" | cut -c12-)
	WALLETADDRESS=$(shidod debug addr $ADDRESS --home $HOMEDIR --keyring-backend $KEYRING | grep "Address (EIP-55)" | cut -c12-)
	echo "========================================================================================================================"
	echo "Shido Eth Hex Address==== "$WALLETADDRESS
	echo "========================================================================================================================"
fi

#========================================================================================================================================================
# Start the node
# shidod start --home "$HOMEDIR"
# Define variables
PLIST_PATH="$HOME/Library/LaunchAgents/com.shido.myservice.plist"

# Create the plist content
PLIST_CONTENT="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>Label</key>
    <string>com.shido.myservice</string>
    <key>ProgramArguments</key>
    <array>
        <string>${INSTALL_PATH}shidod</string>
        <string>start</string>
        <string>--home</string>
        <string>${HOMEDIR}</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>${HOME}/logfile.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/another_logfile.log</string>
</dict>
</plist>"

# Write the plist content to a temporary file
echo "$PLIST_CONTENT" > /tmp/com.shido.myservice.plist

# Move the temporary file to the final location
sudo mv /tmp/com.shido.myservice.plist "$PLIST_PATH"

# Set the correct ownership and permissions
sudo chown $USER "$PLIST_PATH"
sudo chmod 644 "$PLIST_PATH"

# Load and start the launch agent
launchctl load "$PLIST_PATH"
launchctl start com.shido.myservice
launchctl enable com.shido.myservice
# tail -f $HOME/logfile.log
