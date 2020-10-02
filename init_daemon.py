#!/usr/bin/env python
import os

daemon_tls = '''${daemon_tls}''' == 'True'
private_key = '''${private_key}'''
cert = '''${cert}'''
ca_cert = '''${ca_cert}'''
docker_service = '''[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --tlsverify --tlscacert=/etc/docker/ca.crt --tlscert=/etc/docker/cert.pem --tlskey=/etc/docker/key.pem -H 0.0.0.0:2376 -H unix://
'''
instance_index = int('${instance_index}')
daemon_count = int('${daemon_count}')


def write_or_link(path, content):
    if content[0] == "/":
        os.symlink(content, path)
    else:
        with open(path, "w") as text_file:
            text_file.write(content)


if daemon_tls and instance_index < daemon_count:
    if not os.path.isdir("/etc/docker"):
        os.mkdir("/etc/docker", 0o700)
    write_or_link("/etc/docker/key.pem", private_key)
    write_or_link("/etc/docker/cert.pem", cert)
    write_or_link("/etc/docker/ca.crt", ca_cert)

    if not os.path.isdir("/etc/systemd/system/docker.service.d"):
        os.makedirs("/etc/systemd/system/docker.service.d")
    with open("/etc/systemd/system/docker.service.d/10-enable-tls.conf", "w") as text_file:
        text_file.write(docker_service)
