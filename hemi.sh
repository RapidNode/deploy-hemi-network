#!/bin/bash

function show() {
    echo -e "${BLUE}$1${NC}"
}

check_latest_version() {
    for i in {1..3}; do
        LATEST_VERSION=$(curl -s https://api.github.com/repos/hemilabs/heminetwork/releases/latest | jq -r '.tag_name')
        if [ -n "$LATEST_VERSION" ]; then
            show "Latest version available: $LATEST_VERSION"
            return 0
        fi
        show "Attempt $i: Failed to fetch the latest version. Retrying..."
        sleep 2
    done

    show "Failed to fetch the latest version after 3 attempts. Please check your internet connection or GitHub API limits."
    exit 1
}

check_latest_version


show "Downloading for x86_64 architecture..."
wget --quiet --show-progress "https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz" -O "heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz"
tar -xzf "heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz" > /dev/null
cd "heminetwork_${LATEST_VERSION}_linux_amd64"


show "Generating a new wallet..."
./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
cat ~/popm-address.json

pubkey_hash=$(jq -r '.pubkey_hash' ~/popm-address.json)
priv_key=$(jq -r '.private_key' ~/popm-address.json)
static_fee=100


if systemctl is-active --quiet hemi.service; then
    show "hemi.service is currently running. Stopping and disabling it..."
    sudo systemctl stop hemi.service
    sudo systemctl disable hemi.service
else
    show "hemi.service is not running."
fi


cat << EOF | sudo tee /etc/systemd/system/hemi.service > /dev/null
[Unit]
Description=Hemi Network popmd Service
After=network.target

[Service]
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/popmd
Environment="POPM_BTC_PRIVKEY=$priv_key"
Environment="POPM_STATIC_FEE=$static_fee"
Environment="POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable hemi.service
sudo systemctl start hemi.service
echo
show "PoP mining is successfully srtated"