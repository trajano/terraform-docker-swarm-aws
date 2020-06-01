# Swarm join design

## Determine if there's no swarm in the VPC

Check all instances that are tagged as `manager` that have a ManagerToken

if (none found) {
  then init swarm and store the tokens as a tag
}
else {
  get the instance IP
  and join as manager or worker using the tag
  if (joining as manager) {
    update tags with manager and worker tokens
  }
}

```python
#!/usr/bin/env python
import boto3
from botocore.exceptions import NoCredentialsError
import os
import subprocess
import time
import json
import urllib2

store_join_tokens_as_tags = True

instance_identity = json.load(urllib2.urlopen('http://169.254.169.254/latest/dynamic/instance-identity/document'))
region_name = instance_identity['region']
instance_id = instance_identity['instanceId']
mac = urllib2.urlopen('http://169.254.169.254/latest/meta-data/mac').read().decode()
vpc_id = urllib2.urlopen('http://169.254.169.254/latest/meta-data/network/interfaces/macs/%s/vpc-id' % mac).read().decode()


s3 = boto3.resource('s3', region_name=region_name)
ec2 = boto3.resource('ec2', region_name=region_name)
vpc = ec2.Vpc(vpc_id)
instance = ec2.Instance(instance_id)

def get_swarm_info_vpc_tags():
  tags = {tag['Key']: tag['Value'] for tag in instance.tags}

  print (list(vpc.instances.all()))
  print (instance.tags)
  pass

def join_swarm_vpc_tags(swarm_manager_ip, token):
  pass

def init_swarm_vpc_tags():
  pass

def update_tokens_vpc_tags(manager_token, worker_token):
  pass

def get_swarm_info_s3():
  pass

def join_swarm_s3(swarm_manager_ip, token):
  pass

def init_swarm_s3():
  pass

def update_tokens_s3(manager_token, worker_token):
  pass

def is_manager_role():
  pass

get_swarm_info = get_swarm_info_vpc_tags
init_swarm = init_swarm_vpc_tags
join_swarm = join_swarm_vpc_tags
update_tokens = update_tokens_vpc_tags

if not store_join_tokens_as_tags:
  get_swarm_info = store_join_tokens_s3
  init_swarm = init_swarm_s3
  join_swarm = join_swarm_s3
  update_tokens = update_tokens_s3
  
(swarm_manager_ip, manager_token, worker_token) = get_swarm_info()
if swarm_manager_ip != None:
  if is_manager_role():
    join_swarm(swarm_manager_ip, manager_token)
    update_tokens(manager_token, worker_token)
  else: 
    join_swarm(swarm_manager_ip, worker_token)
else:
  (swarm_manager_ip, manager_token, worker_token) = init_swarm()
  update_tokens(manager_token, worker_token)

"""
```
"""
