#!/usr/bin/env python
import boto3
import os
import subprocess

# Load system daemons
subprocess.check_call(["systemctl", "daemon-reload"])
subprocess.check_call(["systemctl", "enable", "haveged.service"])
subprocess.check_call(["systemctl", "enable", "docker.service"])
subprocess.check_call(["systemctl", "start", "haveged.service"])
subprocess.check_call(["systemctl", "start", "docker.service"])

# Set values loaded by the tempalte
s3_bucket = '${s3_bucket}'
instance_index = int('${instance_index}')
swapsize = int('${swapsize}')

# Set the host name
subprocess.check_call(["hostnamectl", "set-hostname",
                       "worker%d" % instance_index])

s3 = boto3.resource('s3')

worker_token_object = s3.Object(s3_bucket, 'worker_token')
manager0_ip_object = s3.Object(s3_bucket, 'ip0')
worker_token_object.wait_until_exists()
manager0_ip_object.wait_until_exists()

worker_token = worker_token_object.get()['Body'].read()
manager0_ip = manager0_ip_object.get()['Body'].read()
subprocess.check_call(
    ["docker", "swarm", "join", "--token", worker_token, manager0_ip])

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
