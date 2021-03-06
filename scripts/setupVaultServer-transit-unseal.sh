#!/usr/bin/env bash

export PATH=$PATH:/usr/local/bin

# get relevant data from the data file
TRANSIT_VAULT_ADDRESS=$(awk -F= -v key="transit_vault_address" '$1==key {print $2}' /vagrant/data.txt)
TRANSIT_KEY=$(awk -F= -v key="transit_key_name" '$1==key {print $2}' /vagrant/data.txt)
TRANSIT_MOUNT=$(awk -F= -v key="transit_mount_path" '$1==key {print $2}' /vagrant/data.txt)
TRANSIT_TOKEN=$(awk -F= -v key="transit_token" '$1==key {print $2}' /vagrant/data.txt)

echo "Installing Vault enterprise version ..."
cp /vagrant_data/vault-enterprise_*.zip ./vault.zip

unzip vault.zip
chown root:root vault
chmod 0755 vault
mv vault /usr/local/bin
rm -f vault.zip

echo "Creating Vault service account ..."
useradd -r -d /etc/vault -s /bin/false vault

echo "Creating directory structure ..."
mkdir -p /etc/vault/pki
chown -R root:vault /etc/vault
chmod -R 0750 /etc/vault

mkdir /var/{lib,log}/vault
chown vault:vault /var/{lib,log}/vault
chmod 0750 /var/{lib,log}/vault

echo "Creating Vault configuration ..."
# echo 'export VAULT_ADDR="http://localhost:8200"' | tee /etc/profile.d/vault.sh

# Add the environment variables for Vault 
tee /etc/profile.d/vault.sh << EOF
export VAULT_ADDR="http://localhost:8200"
EOF


NETWORK_INTERFACE=$(ls -1 /sys/class/net | grep -v lo | sort -r | head -n 1)
IP_ADDRESS=$(ip address show $NETWORK_INTERFACE | awk '{print $2}' | egrep -o '([0-9]+\.){3}[0-9]+')
HOSTNAME=$(hostname -s)

tee /etc/vault/vault.hcl << EOF
api_addr = "http://${IP_ADDRESS}:8200"
cluster_addr = "https://${IP_ADDRESS}:8201"
ui = true

seal "transit" {
  address            = "${TRANSIT_VAULT_ADDRESS}"
  token              = "${TRANSIT_TOKEN}"
  disable_renewal    = "false"

  // Key configuration
  key_name           = "${TRANSIT_KEY}"
  mount_path         = "${TRANSIT_MOUNT}"
}

storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  cluster_addr  = "${IP_ADDRESS}:8201"
  tls_disable   = "true"
}
EOF

chown root:vault /etc/vault/vault.hcl
chmod 0640 /etc/vault/vault.hcl

tee /etc/systemd/system/vault.service << EOF
[Unit]
Description="Vault secret management tool"
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault/vault.hcl

[Service]
User=vault
Group=vault
PIDFile=/var/run/vault/vault.pid
ExecStart=/usr/local/bin/vault server -config=/etc/vault/vault.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=42
TimeoutStopSec=30
StartLimitInterval=60
StartLimitBurst=3
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl enable vault
systemctl restart vault
