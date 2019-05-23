# Vault Auto Unseal Feature using AWS KMS Setup
This folder has a vagrant file to create a Vault Cluster with Consul backend.  
Seal stanza is added to the Vault config file to setup auto unseal using AWS KMS. 

This Vault cluster will be used to as a Transit Engine for auto unseal a separate Vault cluster defined in the ```secondary``` folder.

Vagrant file has code block to create a secondary cluster with auto unseal with AWS KMS using a different KMS ring.  This secondary can be configured as a DR or Performance Replication to perform further tests.

Each cluster contains 2 nodes and each note consists of a Consul Server and Vault server.  
The configuration is used for learning purposes.  This is NOT following the reference architecture for Vault and should not be used for a Production setup.

```
Cluster 1: Vault Primary cluster in DC1 

Cluster 2: Vault Secondary cluster in DC2 

```

All servers are set without TLS.

## Pre-Requisites
Create a folder named as ```ent``` and copy both the Consul and Vault enterprise binary zip files

```e.g., consul-enterprise_1.4.5+prem_linux_amd64.zip```

Rename ```data.txt.example``` to ```data.txt``` and update the values to specify the AWS related information such as Region, Access Key, Secret Key and AWS KMD Id.

## Vault Primary Cluster
2 node cluster is created with each node containing Vault and Consul servers. The server details are shown below

```
vault1   10.100.1.11
vault2   10.100.1.12
```

One of the Consul servers would become the leader.  Similarly one of Vault servers would become the Active node and the other node acts as Read Replica.

## Vault Secondary Cluster
2 node cluster is created with each node containing Vault and Consul servers. The server details are shown below

```
vault-dr1   10.100.2.11
vault-dr2   10.100.2.12
```

The vagrant file also has commented section to create another secondary cluster if required.  Check the content of the Vagrant file.

## Usage
If the ubuntu box is not available then it will take sometime to download the base box for the first time.  After the initial download, servers can be destroyed and recreated quickly with Vagrant

```
$vagrant up

$vagrant status

```

To check the status of the servers ssh into one of the nodes and check the cluster members and identify the leader.

```
$vagrant ssh vault1

vagrant@v1: $consul members

Node  Address           Status  Type    Build      Protocol  DC   Segment
v1    10.100.1.11:8301  alive   server  1.5.0+ent  2         dc1  <all>
v2    10.100.1.12:8301  alive   server  1.5.0+ent  2         dc1  <all>

vagrant@v1: $consul operator raft list-peers 

Node  ID                                    Address           State     Voter  RaftProtocol
v1    8c50f7de-634e-d7ee-17b8-7f904a34434d  10.100.1.11:8300  leader    true   3
v2    b3100f83-a4d1-89fd-5ab3-d96951e6a342  10.100.1.12:8300  follower  true   3

vagrant@v1: $consul info

vagrant@v1: $vault status

Key                      Value
---                      -----
Recovery Seal Type       awskms
Initialized              false
Sealed                   true
Total Recovery Shares    0
Threshold                0
Unseal Progress          0/0
Unseal Nonce             n/a
Version                  n/a
HA Enabled               true

```

If ```vault status``` throws an error then check the AWS related information specified in the ```data.txt``` file.

Vault status would be shown as uninitialised and sealed.  By default the Recovery Seal Type is set to ```awskms```.

## Initialising and Unsealing Vault

Perform the following to initialise the Vault cluster and this should unseal both vault nodes due to ```awskms``` stanza.  
Initialisation is only required at one of the servers.

Vault can be initialised with Recovery keys.  In this case, the Recovery Seal Type would be set to ```Shamir```
If no recovery keys are requested then Recovery Seal Type would remain as ```awskms```
Having Recovery Keys would be useful as a last resort in case ```aws kms``` is accidently removed.

```
$vagrant ssh vault1

vagrant@v1: $vault status

vagrant@v1: $vault operator init -recovery-shares=1 recovery-threshold=1
Recovery Key 1: G25YBN1CvXjTSbSxuJTGLSzoK/RAkbrvPwJU7gM+KFc=

Initial Root Token: s.WSsEUEqEOmYEAhK26AQy1iZ9

Success! Vault is initialized

Recovery key initialized with 1 key shares and a key threshold of 1. Please
securely distribute the key shares printed above.

vagrant@v1:~$ vault status
Key                      Value
---                      -----
Recovery Seal Type       shamir
Initialized              true
Sealed                   false
Total Recovery Shares    1
Threshold                1
Version                  1.1.2+prem
Cluster Name             vault-cluster-9d6f6589
Cluster ID               f1f3e2e7-59c9-0471-c07e-4940eb1e1693
HA Enabled               true
HA Cluster               https://10.100.1.11:8201
HA Mode                  active
Last WAL                 16

vagrant@v1: $exit

$vagrant ssh vault2

vagrant@v2:~$ vault status
Key                                    Value
---                                    -----
Recovery Seal Type                     shamir
Initialized                            true
Sealed                                 false
Total Recovery Shares                  1
Threshold                              1
Version                                1.1.2+prem
Cluster Name                           vault-cluster-9d6f6589
Cluster ID                             f1f3e2e7-59c9-0471-c07e-4940eb1e1693
HA Enabled                             true
HA Cluster                             https://10.100.1.11:8201
HA Mode                                standby
Active Node Address                    http://10.100.1.11:8200
Performance Standby Node               true
Performance Standby Last Remote WAL    0

```

## Testing Auto Unseal Feature

Once the Vault is initialised, it would be unsealed by the use of AWS KMS.   This is verified in the previous step.

When Vault is restarted, it would automatically unseal using AWS KMS.

```
vagrant@v2: $ sudo systemctl stop vault
vagrant@v2: $ sudo systemctl start vault

vagrant@v2:~$ vault status
Key                                    Value
---                                    -----
Recovery Seal Type                     shamir
Initialized                            true
Sealed                                 false
Total Recovery Shares                  1
Threshold                              1
Version                                1.1.2+prem
Cluster Name                           vault-cluster-9d6f6589
Cluster ID                             f1f3e2e7-59c9-0471-c07e-4940eb1e1693
HA Enabled                             true
HA Cluster                             https://10.100.1.11:8201
HA Mode                                standby
Active Node Address                    http://10.100.1.11:8200
Performance Standby Node               true
Performance Standby Last Remote WAL    0

```

## Accessing UI

Use one of the server nodes to access the Consul UI on port 8500 and the Vault UI on port 8200.  The UI for Consul will not work if the leader is not elected.

e.g., Consul UI http://10.100.1.11:8500 

e.g., Vault UI http://10.100.2.11:8500 


## Create Token For Transit Auto Unseal

In order to use this current Vault cluster as a Transit Engine to auto unseal another Vault Cluster, the following needs to happen.

1. Login to the Vault cluster with an admin token. For the test root token is used but always delete the root token after creating admin token with admin policy
2. Enable Transit Engine
3. Create a Transit Key
4. Create a Policy to enable update capabilities at the encrypt and decrypt paths of the key
5. Create a token by attaching the above policy
6. Use this token and the Vault address in the other Vault cluster to configure transit auto unseal


```
vagrant@v1:~$ vault login s.WSsEUEqEOmYEAhK26AQy1iZ9
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                s.WSsEUEqEOmYEAhK26AQy1iZ9
token_accessor       5U8f3PkWNi1LEgj53zpzOekd
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]

vagrant@v1:~$ vault secrets enable transit
Success! Enabled the transit secrets engine at: transit/

vagrant@v1:~$ vault write -f transit/keys/transit-auto-unseal-key
Success! Data written to: transit/keys/transit-auto-unseal-key

vagrant@v1:~$ cat auto-unseal-policy.hcl
path "transit/encrypt/transit-auto-unseal-key" {
  capabilities = ["update"]
}

path "transit/decrypt/transit-auto-unseal-key" {
  capabilities = ["update"]
}

vagrant@v1:~$ vault policy write transit_autounseal-policy auto-unseal-policy.hcl
Success! Uploaded policy: transit_autounseal-policy

vagrant@v1:~$ vault token create -policy="transit_autounseal-policy"
Key                  Value
---                  -----
token                s.oqkuvULbV41UW9u8wlRDCGaK
token_accessor       dtF12CRHHFK2shE3hPNY4f5E
token_duration       768h
token_renewable      true
token_policies       ["default" "transit_autounseal-policy"]
identity_policies    []
policies             ["default" "transit_autounseal-policy"]

```

Instead of passing the token as shown above, token can be wrapped for appropriate TTL and this wrapped token can be passed to the other Vault cluster.  In this scenario, the other Vault cluster needs to unwrap the wrapped token to get the token before using it in the transit stanza.