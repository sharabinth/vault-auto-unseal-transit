# Vault Auto Unseal Feature using Transit Engine 
This repo has two separate Vault clusters to test the Transit Auto Unseal feature.

The tests can be further extended to do additional tests with a DR setup to the Active Primary cluster which is promoted as a a Primary so that the transit auto unseal can be tested.

Also an additional test could be performed with a Performance Replication setup instead of the DR setup.  In this case, the transit auto unseal test should fail as the tokens are not propagated to the Performance Replication cluster.

Please check the Readme files in the ```primary``` and the ```secondary``` folders.



