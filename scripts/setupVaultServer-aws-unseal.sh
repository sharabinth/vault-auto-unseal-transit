#!/usr/bin/env bash

export PATH=$PATH:/usr/local/bin

# get relevant data from the data file
AWS_KMS_KEY=$(awk -F= -v key=$VAULT_KMS_KEY '$1==key {print $2}' /vagrant/data.txt)
AWS_ACCESS_KEY_ID=$(awk -F= -v key="aws_access_key" '$1==key {print $2}' /vagrant/data.txt)
AWS_SECRET_ACCESS_KEY=$(awk -F= -v key="aws_secret_access_key" '$1==key {print $2}' /vagrant/data.txt)
AWS_REGION=$(awk -F= -v key="aws_region" '$1==key {print $2}' /vagrant/data.txt)

echo "Installing Vault enterprise version ..."
#cp /vagrant/ent/vault-enterprise_*.zip ./vault.zip
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

# Add the environment variables for Vault including AWS keys for auto unseal
# somehow the AWS environment variables are not used by Vault for the seal stranza therefore all these
# details are included in the HCL config file
tee /etc/profile.d/vault.sh << EOF
export VAULT_ADDR="http://localhost:8200"
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_REGION=$AWS_REGION
EOF


NETWORK_INTERFACE=$(ls -1 /sys/class/net | grep -v lo | sort -r | head -n 1)
IP_ADDRESS=$(ip address show $NETWORK_INTERFACE | awk '{print $2}' | egrep -o '([0-9]+\.){3}[0-9]+')
HOSTNAME=$(hostname -s)

tee /etc/vault/vault.hcl << EOF
api_addr = "http://${IP_ADDRESS}:8200"
cluster_addr = "https://${IP_ADDRESS}:8201"
ui = true

seal "awskms" {
  region     = "${AWS_REGION}"
  access_key = "${AWS_ACCESS_KEY_ID}"
  secret_key = "${AWS_SECRET_ACCESS_KEY}"
  kms_key_id = "${AWS_KMS_KEY}"
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
