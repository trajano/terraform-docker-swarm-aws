#!/usr/bin/env python
import os

private_key = '''${private_key}'''
cert = '''${cert}'''
ca_cert = '''${ca_cert}'''
docker_service = '''[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --tlsverify --tlscacert=/etc/docker/ca.crt --tlscert=/etc/docker/cert.pem --tlskey=/etc/docker/key.pem -H 0.0.0.0:2376 -H unix://
'''
instance_index = int('${instance_index}')
daemon_count = int('${daemon_count}')
if instance_index < daemon_count:
    if (not os.path.isdir("/etc/docker")):
      os.mkdir("/etc/docker", 0o700)
    with open("/etc/docker/key.pem", "w") as text_file:
        text_file.write(private_key)
    with open("/etc/docker/cert.pem", "w") as text_file:
        text_file.write(cert)
    with open("/etc/docker/ca.crt", "w") as text_file:
        text_file.write(ca_cert)

    if (not os.path.isdir("/etc/systemd/system/docker.service.d")):
      os.makedirs("/etc/systemd/system/docker.service.d")
    with open("/etc/systemd/system/docker.service.d/10-enable-tls.conf",  "w") as text_file:
        text_file.write(docker_service)
