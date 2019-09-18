#!/usr/bin/env python
import boto3
from botocore.exceptions import NoCredentialsError
import os
import subprocess
import time

# Load system daemons
subprocess.check_call(["systemctl", "daemon-reload"])
subprocess.check_call(["systemctl", "enable", "docker.service"])
subprocess.check_call(["systemctl", "start", "docker.service"])

# Set values loaded by the template
s3_bucket = '${s3_bucket}'
region_name = '${region_name}'
instance_index = int('${instance_index}')
swapsize = int('${swapsize}')
vpc_name = '${vpc_name}'

# Set the host name
subprocess.check_call(["hostnamectl", "set-hostname",
                       "manager%d-%s" % (instance_index, vpc_name)])

s3 = boto3.resource('s3', region_name=region_name)


def initialize_swarm():
    """
    Initializes an empty swarm and stores the tokens into S3.
    """
    subprocess.check_call(["docker", "swarm", "init"])
    manager_token = subprocess.check_output(
        ["docker", "swarm", "join-token", "-q", "manager"]).strip()
    manager_token_object = s3.Object(s3_bucket, 'manager_token')
    manager_token_object.put(Body=bytes(manager_token),
                             StorageClass="ONEZONE_IA")

    worker_token = subprocess.check_output(
        ["docker", "swarm", "join-token", "-q", "worker"]).strip()
    worker_token_object = s3.Object(s3_bucket, 'worker_token')
    worker_token_object.put(Body=bytes(worker_token),
                            StorageClass="ONEZONE_IA")


try:
    bucket = s3.Bucket(s3_bucket)
    bucket.objects.all()
except NoCredentialsError as e:
    time.sleep(5)

if instance_index == 0:
    # if this is the first node, check if there exists a manager token and ip1 file
    # the presence of these indicate that a swarm is already existing so it should
    # try to rejoin the swarm

    bucket = s3.Bucket(s3_bucket)
    objects = map(lambda o: o.key, bucket.objects.all())
    if 'ip1' in objects and 'manager_token' in objects:
        manager_token_object = s3.Object(s3_bucket, 'manager_token')
        manager_token = manager_token_object.get()['Body'].read()
        manager1_ip_object = s3.Object(s3_bucket, 'ip1')
        manager1_ip = manager1_ip_object.get()['Body'].read()

        try:
            subprocess.check_output(
                ["docker", "swarm", "join", "--token", manager_token, manager1_ip], stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError as err:
            initialize_swarm()
    else:
        initialize_swarm()
else:
    manager_token_object = s3.Object(s3_bucket, 'manager_token')
    manager0_ip_object = s3.Object(s3_bucket, 'ip0')
    manager_token_object.wait_until_exists()
    manager0_ip_object.wait_until_exists()

    manager_token = manager_token_object.get()['Body'].read()
    manager0_ip = manager0_ip_object.get()['Body'].read()
    subprocess.check_call(
        ["docker", "swarm", "join", "--token", manager_token, manager0_ip])

myip = subprocess.check_output(
    ["curl", "-s", "http://169.254.169.254/latest/meta-data/local-ipv4"]).strip()
myip_object = s3.Object(s3_bucket, 'ip%d' % instance_index)
myip_object.put(Body=bytes(myip), StorageClass="ONEZONE_IA")

f = open("/swapfile", "wb")
for i in xrange(swapsize * 1024):
    f.write("\0" * 1024 * 1024)
f.close()
os.chmod("/swapfile", 0o600)
subprocess.check_output(["mkswap", "/swapfile"])
f = open("/etc/fstab", "a")
f.write("/swapfile none swap defaults 0 0\n")
f.close()
subprocess.check_output(["swapon", "-a"])
