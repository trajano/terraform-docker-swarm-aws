#!/usr/bin/env python
import os

private_key = '''
${private_key}
'''
cert = '''
${cert}
'''
ca_cert = '''
${ca_cert}
'''
instance_index = int('${instance_index}')
daemon_count = int('${daemon_count}')
if instance_index < daemon_count:
    os.mkdir("/etc/docker", 0700)
    with open("/etc/docker/key.pem", "w") as text_file:
        text_file.write(private_key)
    with open("/etc/docker/cert.pem", "w") as text_file:
        text_file.write(cert)
    with open("/etc/docker/ca.crt", "w") as text_file:
        text_file.write(ca_cert)
