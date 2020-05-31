# AWS Docker Swarm Terraform Module

This is a Terraform configuration that sets up a Docker Swarm on an existing VPC with a configurable amount of managers and worker nodes. The swarm is configured to have TLS enabled.

## Terraformed layout

In the VPC there will be 2 x _number of availability zones in region_ subnets created. Each EC2 instance will be placed in an subnet in a round-robin fashion.

There are no elastic IPs allocated in the module in order to prevent using up the elastic IP allocation for the VPC. It is up to the caller to set that up.

## Prerequisites

The `aws` provider is configured in your TF file.

AWS permissions to do the following

- Manage EC2 resource
- Security Groups
- IAM permissions
- S3 Create and Access

The following is the JSON Policy that works with the `simple` example.  Note this is not fully trimmed down, but a lot of the operations are restricted.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "iam:GetPolicyVersion",
                "ec2:AuthorizeSecurityGroupIngress",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:CreateRole",
                "s3:CreateBucket",
                "iam:AttachRolePolicy",
                "iam:AddRoleToInstanceProfile",
                "ec2:ReplaceRoute",
                "ec2:DeleteRouteTable",
                "s3:GetBucketObjectLockConfiguration",
                "iam:DetachRolePolicy",
                "ec2:StartInstances",
                "iam:ListAttachedRolePolicies",
                "ec2:CreateRoute",
                "ec2:RevokeSecurityGroupEgress",
                "s3:PutLifecycleConfiguration",
                "ec2:DeleteInternetGateway",
                "iam:GetRole",
                "iam:GetPolicy",
                "s3:GetBucketWebsite",
                "ec2:CreateTags",
                "iam:DeleteRole",
                "ec2:RunInstances",
                "ec2:StopInstances",
                "ec2:CreateVolume",
                "s3:GetReplicationConfiguration",
                "ec2:RevokeSecurityGroupIngress",
                "s3:PutBucketObjectLockConfiguration",
                "iam:CreateInstanceProfile",
                "s3:GetLifecycleConfiguration",
                "s3:GetBucketTagging",
                "ec2:DeleteTags",
                "s3:PutAccelerateConfiguration",
                "s3:ListBucketVersions",
                "s3:GetBucketLogging",
                "iam:DeletePolicy",
                "s3:ListBucket",
                "s3:GetAccelerateConfiguration",
                "iam:ListInstanceProfilesForRole",
                "s3:GetEncryptionConfiguration",
                "iam:PassRole",
                "s3:PutBucketTagging",
                "s3:GetBucketRequestPayment",
                "s3:DeleteBucket",
                "iam:DeleteInstanceProfile",
                "s3:GetBucketPublicAccessBlock",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:TerminateInstances",
                "s3:PutBucketPublicAccessBlock",
                "iam:GetInstanceProfile",
                "ec2:DeleteRoute",
                "s3:GetBucketVersioning",
                "iam:CreatePolicy",
                "iam:ListPolicyVersions",
                "ec2:DeleteSecurityGroup",
                "s3:GetBucketCORS",
                "s3:GetBucketLocation",
                "iam:DeletePolicyVersion"
            ],
            "Resource": [
                "arn:aws:iam::*:policy/*",
                "arn:aws:iam::*:instance-profile/*",
                "arn:aws:iam::*:role/*",
                "arn:aws:ec2:*:*:subnet/*",
                "arn:aws:ec2:*:*:vpn-gateway/*",
                "arn:aws:ec2:*:*:transit-gateway-route-table/*",
                "arn:aws:ec2:*:*:reserved-instances/*",
                "arn:aws:ec2:*:*:client-vpn-endpoint/*",
                "arn:aws:ec2:*:*:vpn-connection/*",
                "arn:aws:ec2:*::snapshot/*",
                "arn:aws:ec2:*:*:security-group/*",
                "arn:aws:ec2:*:*:network-acl/*",
                "arn:aws:ec2:*:*:network-interface/*",
                "arn:aws:ec2:*:*:capacity-reservation/*",
                "arn:aws:ec2:*:*:internet-gateway/*",
                "arn:aws:ec2:*:*:route-table/*",
                "arn:aws:ec2:*:*:dhcp-options/*",
                "arn:aws:ec2:*::spot-instance-request/*",
                "arn:aws:ec2:*:*:instance/*",
                "arn:aws:ec2:*:*:transit-gateway/*",
                "arn:aws:ec2:*:*:volume/*",
                "arn:aws:ec2:*::fpga-image/*",
                "arn:aws:ec2:*:*:vpc/*",
                "arn:aws:ec2:*:*:transit-gateway-attachment/*",
                "arn:aws:ec2:*::image/*",
                "arn:aws:s3:::*"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:ReplaceRouteTableAssociation",
                "ec2:AttachInternetGateway",
                "ec2:DescribeSnapshots",
                "ec2:ReportInstanceStatus",
                "ec2:DescribeHostReservationOfferings",
                "ec2:DescribeVolumeStatus",
                "ec2:CreateInternetGateway",
                "ec2:DescribeVolumes",
                "ec2:DescribeFpgaImageAttribute",
                "ec2:DescribeExportTasks",
                "ec2:DescribeKeyPairs",
                "ec2:DescribeCapacityReservations",
                "ec2:DescribeClientVpnRoutes",
                "ec2:DescribeSpotFleetRequestHistory",
                "ec2:DescribeVpcClassicLinkDnsSupport",
                "ec2:DescribeSnapshotAttribute",
                "ec2:DescribeIdFormat",
                "ec2:DisassociateRouteTable",
                "ec2:DescribeVolumeAttribute",
                "ec2:DescribeImportSnapshotTasks",
                "ec2:DescribeVpcEndpointServicePermissions",
                "ec2:DescribeTransitGatewayAttachments",
                "ec2:DescribeImageAttribute",
                "ec2:DescribeFleets",
                "ec2:DescribeSubnets",
                "ec2:CreateSubnet",
                "ec2:DisassociateAddress",
                "ec2:DescribeMovingAddresses",
                "ec2:DescribeFleetHistory",
                "ec2:DescribePrincipalIdFormat",
                "ec2:DescribeFlowLogs",
                "ec2:DescribeRegions",
                "ec2:CreateVpc",
                "ec2:DescribeTransitGateways",
                "ec2:DescribeVpcEndpointServices",
                "ec2:DescribeSpotInstanceRequests",
                "ec2:DescribeVpcAttribute",
                "ec2:ModifySubnetAttribute",
                "ec2:ExportClientVpnClientCertificateRevocationList",
                "ec2:DescribeTransitGatewayRouteTables",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeNetworkInterfaceAttribute",
                "ec2:DescribeVpcEndpointConnections",
                "ec2:DescribeInstanceStatus",
                "ec2:ReleaseAddress",
                "ec2:DescribeHostReservations",
                "ec2:DescribeBundleTasks",
                "ec2:DescribeIdentityIdFormat",
                "ec2:DescribeClassicLinkInstances",
                "ec2:DescribeVpcEndpointConnectionNotifications",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeFpgaImages",
                "s3:ListAllMyBuckets",
                "ec2:DescribeVpcs",
                "ec2:DescribeStaleSecurityGroups",
                "ec2:DeleteSubnet",
                "ec2:DescribeAggregateIdFormat",
                "ec2:ExportClientVpnClientConfiguration",
                "ec2:DescribeClientVpnConnections",
                "ec2:DescribeByoipCidrs",
                "ec2:DescribePlacementGroups",
                "ec2:AssociateRouteTable",
                "ec2:DescribeInternetGateways",
                "ec2:SearchTransitGatewayRoutes",
                "ec2:DescribeSpotDatafeedSubscription",
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeNetworkInterfacePermissions",
                "s3:HeadBucket",
                "ec2:DescribeNetworkAcls",
                "ec2:DescribeRouteTables",
                "ec2:DescribeClientVpnEndpoints",
                "ec2:DescribeEgressOnlyInternetGateways",
                "ec2:DescribeLaunchTemplates",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:CreateRouteTable",
                "ec2:GetTransitGatewayAttachmentPropagations",
                "ec2:DescribeFleetInstances",
                "ec2:DescribeClientVpnTargetNetworks",
                "ec2:DetachInternetGateway",
                "ec2:DescribeVpcEndpointServiceConfigurations",
                "ec2:DescribePrefixLists",
                "ec2:DescribeInstanceCreditSpecifications",
                "ec2:DescribeVpcClassicLink",
                "ec2:GetTransitGatewayRouteTablePropagations",
                "ec2:DeleteVpc",
                "ec2:DescribeVpcEndpoints",
                "ec2:AssociateAddress",
                "ec2:DescribeVpnGateways",
                "ec2:DescribeAddresses",
                "ec2:DescribeInstanceAttribute",
                "ec2:DescribeDhcpOptions",
                "ec2:DescribeSpotPriceHistory",
                "ec2:DescribeNetworkInterfaces",
                "ec2:CreateSecurityGroup",
                "ec2:ModifyVpcAttribute",
                "ec2:ModifyInstanceAttribute",
                "ec2:GetTransitGatewayRouteTableAssociations",
                "ec2:DescribeIamInstanceProfileAssociations",
                "ec2:DescribeTags",
                "ec2:DescribeLaunchTemplateVersions",
                "ec2:DescribeImportImageTasks",
                "ec2:DescribeNatGateways",
                "ec2:DescribeCustomerGateways",
                "ec2:AllocateAddress",
                "ec2:DescribeSpotFleetRequests",
                "ec2:DescribeHosts",
                "ec2:DescribeImages",
                "ec2:DescribeSpotFleetInstances",
                "ec2:DescribeSecurityGroupReferences",
                "ec2:DescribePublicIpv4Pools",
                "ec2:DescribeClientVpnAuthorizationRules",
                "ec2:DescribeTransitGatewayVpcAttachments",
                "ec2:DescribeConversionTasks"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor2",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:GetObjectVersion"
            ],
            "Resource": "arn:aws:s3:::*/*"
        }
    ]
}
```

## Secure Docker daemon port

**DEPRECATION NOTICE** Docker TLS daemon support will be removed in a future releases.  Use [SSH to connect to the Docker Daemon][ssh-daemon].

The first few _manager_ nodes will expose port 2376. For TLS to work, the following are required

- elastic IP for remote connections. These will determine the number of servers that will have TLS enabled.
- public host names the docker port to add to the SANs.
- private key data for each server needs to be provided, this should match the amount of elastic IPs being created.
- signed certificate for each server needs to be provided. The CSR will be provided by the module.
- CA certificate.

When present a systemd drop-in file is added to `/etc/systemd/system/docker.service.d` to enable

    --tlsverify
    --tlscacert=ca.pem
    --tlscert=server-cert.pem
    --tlskey=server-key.pem
    -H 0.0.0.0:2376
    -H unix://

As noted in https://www.terraform.io/docs/providers/tls/r/private_key.html

> **Important Security Notice** The private key generated by this resource will be stored _unencrypted_ in your Terraform state file. **Use of this resource for production deployments is not recommended.** Instead, generate a private key file outside of Terraform and distribute it securely to the system where Terraform will be run.

As such the module does not create the private keys (though the example will show how to do it using Terraform). However, the CSRs are still created by the module and it is expected that Terraform will convert it to a CSR.

If you want to use elastic IPs but not expose the Docker socket you just leave the `daemon_count` as `0` (default).

## Limitations

- Maximum of 240 docker managers.
- Maximum of 240 docker workers.
- Only one VPC and therefore only one AWS region.
- The VPC must have to following properties
  - The VPC should have access to the Internet
  - The DNS hostnames support must be enabled (otherwise the node list won't work too well)
  - VPC must have a CIDR block mask of `/16`.

## Example

The `examples/simple` folder shows an example of how to use this module.

## Usage of S3

S3 was used because EFS and SimpleDB (both better choices in terms of cost and function) are NOT available in `ca-central-1` and likely some other non-US regions.

## Cloud Config merging

The default merge rules of cloud-config is used which may yield unexpected results (see [cloudconfig merge behaviours](https://jen20.com/2015/10/04/cloudconfig-merging.html)) if you are changing existing keys. To bring back the merge behaviour from 1.2 add

    merge_how: "list(append)+dict(recurse_array)+str()"

## Upgrading the swarm

Though `yum update` can simply update the software, it may be required to update things that are outside such as updates to the module itself, `cloud_config_extra` information or AMI updates.  For this to work, you need to have at least 3 managers otherwise you'd lose raft consensus and have to rebuild the swarm from scratch.

### Example of how to upgrade a 3 manager swawrm

Upgrading a 3 manager swarm needs to be done one at a time to prevent raft consensus loss.

1. ssh to `manager0`
2. Leave the swarm by executing  `sudo /root/bin/leave-swarm.sh`
3. Taint `manager0` from the command line `terraform taint --module=docker-swarm aws_instance.managers.0`
4. Rebuild `manager0` from the command line `terraform apply`
5. ssh to `manager1`
6. Wait until `manager0` rejoins the swarm by checking `docker node ls`
7. Leave the swarm by executing  `sudo /root/bin/leave-swarm.sh`
8. Taint `manager1` from the command line `terraform taint --module=docker-swarm aws_instance.managers.1`
9. Rebuild `manager1` from the command line `terraform apply`
10. ssh to `manager2`
11. Wait until `manager1` rejoins the swarm by checking `docker node ls`
12. Leave the swarm by executing  `sudo /root/bin/leave-swarm.sh`
13. Taint `manager2` from the command line `terraform taint --module=docker-swarm aws_instance.managers.2`
14. Rebuild `manager2` from the command line `terraform apply`
15. ssh to `manager0`
16. Wait until `manager2` rejoins the swarm by checking `docker node ls`
17. Prune the nodes that are down and are drained `sudo /root/bin/prune-nodes.sh`

### Upgrading the worker nodes

A future relase of this would utilize auto-scaling for now this needs to be done manually

1. ssh to `manager0`
2. Drain and remove the worker node(s) from the swarm using `sudo /root/bin/rm-workers.sh <nodename[s]>`
3. Taint the workers that are removed from the command line `terraform taint --module=docker-swarm aws_instance.worker.#`
4. Rebuild the workers from the command line `terraform apply`

## Other tips

* Support for exposing the Docker daemon and removal is expected on 5.0.  It is recommended to switch to [use SSH to access to the Docker daemon][ssh-daemon] as it forgoes managing certificates.
* Don't use Terraform to provision your containers, just let it build the infrastructure and add the hooks to connect it to your build system.
* The TLS example uses keys that are generated and stored in Terraform state.  This is risky as the keys are stored unencrypted.  That being said, there is no need to use the certificate request that is generated by the module, a set of presigned keys and certificates for the servers can be provided.
* To use a different version of Docker create a custom cloud config with 

    packages:
      - [docker, 18.03.1ce-2.amzn2]
      - python2-boto3
      - yum-cron

* If the private key or certificate is not locally available.  `create_daemon_certificate_request` should be set to `false`.

[ssh-daemon]: https://github.com/docker/cli/pull/1014
