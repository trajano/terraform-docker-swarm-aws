# TLS example

This example shows how to set up a Docker swarm with exposed TLS enabled ports.

## Connecting to the Docker daemon

    export DOCKER_CERT_PATH=<directory where you're extracting the PEM files>
    export DOCKER_TLS_VERIFY=1
    export DOCKER_HOST=tcp://<ip>:2376
    terraform output client_private_key_pem > key.pem
    terraform output client_cert_pem > cert.pem
    terraform output ca_cert_pem > ca.pem
