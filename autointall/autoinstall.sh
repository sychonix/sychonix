#!/bin/bash

GREEN="\e[1m\e[1;32m"    # hijau tebal
RED="\e[1m\e[1;31m"      # merah tebal
BLUE='\033[0;34m'        # biru
NC="\e[0m"               # tanpa warna
YELLOW='\033[1;33m'      # kuning
PURPLE='\033[0;35m'      # ungu
CYAN='\033[0;36m'        # cyan
WHITE='\033[1;37m'       # putih
ORANGE='\033[0;33m'      # oranye
PINK='\033[1;35m'        # pink

source <(curl -s https://raw.githubusercontent.com/sychonix/sychonix/main/autointall/common.sh)

printLogo

echo -e "${CYAN}Enter WALLET name:${NC}"
read -p "" WALLET
echo 'export WALLET='$WALLET
echo -e "${CYAN}Enter your MONIKER:${NC}"
read -p "" MONIKER
echo 'export MONIKER='$MONIKER
echo -e "${CYAN}Enter your PORT (for example 17, default port=26):${NC}"
read -p "" PORT
echo 'export PORT='$PORT

# set vars
echo "export WALLET="$WALLET"" >> $HOME/.bash_profile
echo "export MONIKER="$MONIKER"" >> $HOME/.bash_profile
echo "export symphonyd_CHAIN_ID="symphony-testnet-2"" >> $HOME/.bash_profile
echo "export SYMPHONY_PORT="$PORT"" >> $HOME/.bash_profile
source $HOME/.bash_profile

printLine
echo -e "${YELLOW}Moniker:${NC}        ${GREEN}$MONIKER${NC}"
echo -e "${YELLOW}Wallet:${NC}         ${GREEN}$WALLET${NC}"
echo -e "${YELLOW}Chain id:${NC}       ${GREEN}$symphonyd_CHAIN_ID${NC}"
echo -e "${YELLOW}Node custom port:${NC}  ${GREEN}$SYMPHONY_PORT${NC}"
printLine
sleep 1

printGreen "1. Installing go..." && sleep 1
# install go, if needed
cd $HOME
VER="1.22.3"
wget "https://golang.org/dl/go$VER.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$VER.linux-amd64.tar.gz"
rm "go$VER.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source $HOME/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

echo $(go version) && sleep 1

source <(curl -s https://raw.githubusercontent.com/itrocket-team/testnet_guides/main/utils/dependencies_install)

printGreen "4. Installing binary..." && sleep 1
# download binary
cd $HOME
rm -rf symphony
git clone https://github.com/Orchestra-Labs/symphony
cd symphony
git checkout v0.2.1
make build
echo done

printGreen "5. Configuring and init app..." && sleep 1
# config and init app
symphonyd config node tcp://localhost:${SYMPHONY_PORT}657
symphonyd config keyring-backend os
symphonyd config chain-id symphony-testnet-2
symphonyd init $MONIKER --chain-id symphony-testnet-2
sleep 1
echo done

printGreen "6. Downloading genesis and addrbook..." && sleep 1
# download genesis and addrbook
curl -Ls https://snapshot.sychonix.com/symphony/genesis.json > $HOME/.symphonyd/config/genesis.json 
curl -Ls https://snapshot.sychonix.com/symphony/addrbook.json > $HOME/.symphonyd/config/addrbook.json
sleep 1
echo done

printGreen "7. Adding seeds, peers, configuring custom ports, pruning, minimum gas price..." && sleep 1
# set seeds and peers
SEEDS=""
PEERS="$(curl -sS https://rpc-symphony-t.sychonix.com/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | sed -z 's|\n|,|g;s|.$||')"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.symphonyd/config/config.toml

# set custom ports in app.toml
sed -i.bak -e "s%:1317%:${SYMPHONY_PORT}317%g;
s%:8080%:${SYMPHONY_PORT}080%g;
s%:9090%:${SYMPHONY_PORT}090%g;
s%:9091%:${SYMPHONY_PORT}091%g;
s%:8545%:${SYMPHONY_PORT}545%g;
s%:8546%:${SYMPHONY_PORT}546%g;
s%:6065%:${SYMPHONY_PORT}065%g" $HOME/.symphonyd/config/app.toml


# set custom ports in config.toml file
sed -i.bak -e "s%:26658%:${SYMPHONY_PORT}658%g;
s%:26657%:${SYMPHONY_PORT}657%g;
s%:6060%:${SYMPHONY_PORT}060%g;
s%:26656%:${SYMPHONY_PORT}656%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${SYMPHONY_PORT}656\"%;
s%:26660%:${SYMPHONY_PORT}660%g" $HOME/.symphonyd/config/config.toml

# config pruning
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.symphonyd/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.symphonyd/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.symphonyd/config/app.toml

# set minimum gas price, enable prometheus and disable indexing
sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.0001uempe"|g' $HOME/.symphonyd/config/app.toml
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.symphonyd/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.symphonyd/config/config.toml
sleep 1
echo done

# create service file
sudo tee /etc/systemd/system/symphonyd.service > /dev/null <<EOF
[Unit]
Description=symphonyd node
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/.symphonyd
ExecStart=$(which symphonyd) start --home $HOME/.symphonyd
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

printGreen "8. Downloading snapshot and starting node..." && sleep 1
# reset and download snapshot
symphonyd tendermint unsafe-reset-all --home $HOME/.symphonyd
if curl -s --head curl https://snapshot.sychonix.com/symphony/symphony-latest.tar.lz4 | head -n 1 | grep "200" > /dev/null; then
  curl https://snapshot.sychonix.com/symphony/symphony-latest.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.symphonyd
    else
  echo "${GREEN}No snapshot found${NC}"
fi

# enable and start service
sudo systemctl daemon-reload
sudo systemctl enable symphonyd
sudo systemctl restart symphonyd && sudo journalctl -u symphonyd -f
