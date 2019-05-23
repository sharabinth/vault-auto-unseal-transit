# Vault Auto Unseal Feature using AWS KMS Setup
This folder has a vagrant file to create a Vault Cluster with Consul backend.  
Seal stanza is added to the Vault config file to setup auto unseal using the transit engine of another active fault. 

The cluster contains 2 nodes and each note consists of a Consul Server and Vault server.  
The configuration is used for learning purposes.  This is NOT following the reference architecture for Vault and should not be used for a Production setup.

```
Cluster 1: Vault Primary cluster in DC1 

```

All servers are set without TLS.

## Pre-Requisites
Create a folder named as ```ent``` and copy both the Consul and Vault enterprise binary zip files.  Please note that OSS binaries can be added as transit auto unseal is now supported in the OSS version.

```e.g., consul-enterprise_1.4.5+prem_linux_amd64.zip```

Rename ```data.txt.example``` to ```data.txt``` and update the values to specify the AWS related information such as Region, Access Key, Secret Key and AWS KMD Id.

## Vault Primary Cluster
2 node cluster is created with each node containing Vault and Consul servers. The server details are shown below

```
vault1   10.100.1.11
vault2   10.100.1.12
```

One of the Consul servers would become the leader.  Similarly one of Vault servers would become the Active node and the other node acts as Read Replica.

## Usage
If the ubuntu box is not available then it will take sometime to download the base box for the first time.  After the initial download, servers can be destroyed and recreated quickly with Vagrant

```
$vagrant up

$vagrant status

```

To check the status of the servers ssh into one of the nodes and check the cluster members and identify the leader.

```
$vagrant ssh vault1

vagrant@v1:~$ consul members
Node  Address           Status  Type    Build      Protocol  DC   Segment
v1    10.200.1.11:8301  alive   server  1.5.0+ent  2         dc1  <all>
v2    10.200.1.12:8301  alive   server  1.5.0+ent  2         dc1  <all>

vagrant@v1:~$ consul operator raft list-peers
Node  ID                                    Address           State     Voter  RaftProtocol
v1    e91dfc41-8ad8-b537-0992-b12d8b95c981  10.200.1.11:8300  leader    true   3
v2    84beaf60-f4f2-be69-7917-94b94191f166  10.200.1.12:8300  follower  true   3

vagrant@v1: $consul info

vagrant@v1:~$ vault status
Key                      Value
---                      -----
Recovery Seal Type       transit
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

Vault status would be shown as uninitialised and sealed.  By default the Recovery Seal Type is set to ```transit```.

## Initialising and Unsealing Vault

Perform the following to initialise the Vault cluster and this should unseal both vault nodes due to ```transit``` stanza.  
Initialisation is only required at one of the servers.

Vault can be initialised with Recovery keys.  In this case, the Recovery Seal Type would be set to ```Shamir```
If no recovery keys are requested then Recovery Seal Type would remain as ```transit```

```
$vagrant ssh vault1

vagrant@v1: $vault status

vagrant@v1: $vault operator init -recovery-shares=1 recovery-threshold=1
Recovery Key 1: oZb+uQKSFvuVrKVloUacqHqsxkfk5JuTFOvee1bm27A=

Initial Root Token: s.OBrAZTQfvLkB43XdgLQG8Foc

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
Cluster Name             vault-cluster-46b4dd90
Cluster ID               2789dd5e-44a4-5828-38a7-de1253e7092f
HA Enabled               true
HA Cluster               https://10.200.1.11:8201
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
Cluster Name                           vault-cluster-46b4dd90
Cluster ID                             2789dd5e-44a4-5828-38a7-de1253e7092f
HA Enabled                             true
HA Cluster                             https://10.200.1.11:8201
HA Mode                                standby
Active Node Address                    http://10.200.1.11:8200
Performance Standby Node               true
Performance Standby Last Remote WAL    0

```

## Testing Auto Unseal Feature

Once the Vault is initialised, it would be unsealed by the use of AWS KMS.   This is verified in the previous step.

When Vault is restarted, it would automatically unseal using AWS KMS.

```
vagrant@v2: $ sudo systemctl stop vault

vagrant@v2:~$ sudo systemctl start vault

vagrant@v2:~$ sudo systemctl status vault
  vault.service - "Vault secret management tool"
   Loaded: loaded (/etc/systemd/system/vault.service; enabled; vendor preset: enabled)
   Active: active (running) since Thu 2019-05-23 11:10:05 UTC; 1s ago
 Main PID: 2787 (vault)
    Tasks: 11 (limit: 1152)
   CGroup: /system.slice/vault.service
           └─2787 /usr/local/bin/vault server -config=/etc/vault/vault.hcl

May 23 11:10:05 v2 vault[2787]:                  Version: Vault v1.1.2+prem
May 23 11:10:05 v2 vault[2787]:              Version Sha: c1bd8914ddf4a3e3f7d0b683b0c5670076166932
May 23 11:10:05 v2 vault[2787]: ==> Vault server started! Log data will stream in below:
May 23 11:10:05 v2 vault[2787]: 2019-05-23T11:10:05.877Z [INFO]  core: stored unseal keys supported, attempting fetch
May 23 11:10:05 v2 vault[2787]: 2019-05-23T11:10:05.888Z [INFO]  core: vault is unsealed
May 23 11:10:05 v2 vault[2787]: 2019-05-23T11:10:05.893Z [INFO]  core.cluster-listener: starting listener: listener_address=0.0.0.0:8201
May 23 11:10:05 v2 vault[2787]: 2019-05-23T11:10:05.893Z [INFO]  core.cluster-listener: serving cluster requests: cluster_listen_address=[::]:8201
May 23 11:10:05 v2 vault[2787]: 2019-05-23T11:10:05.894Z [INFO]  core: entering standby mode
May 23 11:10:05 v2 vault[2787]: 2019-05-23T11:10:05.894Z [INFO]  core: performance standby: forwarding client is nil, waiting for new leader
May 23 11:10:05 v2 vault[2787]: 2019-05-23T11:10:05.895Z [INFO]  core: unsealed with stored keys: stored_keys_used=1

```

## Accessing UI

Use one of the server nodes to access the Consul UI on port 8500 and the Vault UI on port 8200.  The UI for Consul will not work if the leader is not elected.

e.g., Consul UI http://10.100.1.11:8500 

e.g., Vault UI http://10.100.2.11:8500 

## More Tests

Setup DR for the Vault cluster used for transit engine for the transit auto unseal feature.

Try to shutdown the other Active Primary Vault cluster and promote DR as the Primary cluster.
This current Vault cluster should continue to auto unseal due to 

Do a similar test with a Performance Replication cluster and the transit auto unseal should not work as the tokens are not replicated to the Performance Replication cluster.