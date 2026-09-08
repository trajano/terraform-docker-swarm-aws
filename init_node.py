#!/usr/bin/env python3
import json
import logging
import os
import os.path
import random
import subprocess
import time
import urllib.request
from datetime import datetime, timezone

import boto3

DAEMON_JSON = "/etc/docker/daemon.json"
logger = logging.getLogger(__name__)
logging.basicConfig(level=os.environ.get("LOGLEVEL", "WARNING"))

# Set values loaded by the template
instance_index = int("${instance_index}")
vpc_name = "${vpc_name}"
group = "${group}"
cloudwatch_log_group = "${cloudwatch_log_group}"
ssh_authorization_method = "${ssh_authorization_method}"

started_on = datetime.now(timezone.utc)
# Global cached results
_current_instance = None


class TokenRequest(urllib.request.Request):
    """
    A urllib request specifically used to obtain the token to access the metadata.
    """

    def __init__(self):
        super().__init__(
            "http://169.254.169.254/latest/api/token",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"},
        )

    def get_method(self, *args, **kwargs):
        return "PUT"


metadata_token = urllib.request.urlopen(TokenRequest()).read()

instance_identity_request = urllib.request.Request(
    "http://169.254.169.254/latest/dynamic/instance-identity/document",
    headers={"X-aws-ec2-metadata-token": metadata_token},
)

# Extract metadata
instance_identity = json.load(urllib.request.urlopen(instance_identity_request))
instance_id = instance_identity["instanceId"]
region_name = instance_identity["region"]

# AWS resources
ec2 = boto3.resource("ec2", region_name=region_name)


def update_daemon_json():
    """
    Updates daemon.json.

    Enables AWS Cloudwatch logging and disables userland-proxy.
    """
    if cloudwatch_log_group == "":
        return

    if os.path.exists(DAEMON_JSON):
        with open(DAEMON_JSON) as json_file:
            daemon_json = json.load(json_file)
    else:
        daemon_json = json.loads("{}")

    daemon_json["log-driver"] = "awslogs"
    daemon_json["log-opts"] = {
        "awslogs-group": cloudwatch_log_group,
        "tag": "{{.Name}}",
    }
    daemon_json["userland-proxy"] = False

    with open(DAEMON_JSON, "w") as json_file:
        json_file.write(json.dumps(daemon_json))


def initialize_system_daemons_and_hostname():
    """
    Load system daemons and host name
    """
    subprocess.check_call(["systemctl", "daemon-reload"])
    subprocess.check_call(["systemctl", "enable", "docker.service"])
    subprocess.check_call(["systemctl", "start", "docker.service"])

    list_unit_files = subprocess.check_output(["systemctl", "list-unit-files"]).decode(
        "utf-8"
    )
    if "dnf-automatic.service" in list_unit_files:
        subprocess.check_call(["systemctl", "enable", "dnf-automatic"])
        subprocess.check_call(["systemctl", "start", "dnf-automatic"])

    subprocess.check_call(
        ["hostnamectl", "set-hostname", f"{group}{instance_index:d}-{vpc_name}"]
    )


# def create_swap():
#     """
#     Initializes and registers the swap volume
#     """
#     subprocess.check_call(["mkswap", "/dev/xvdf"])
#     f = open("/etc/fstab", "a")
#     f.write("/dev/xvdf none swap defaults 0 0\n")
#     f.close()
#     subprocess.check_call(["swapon", "-a"])


def initialize_swarm():
    """
    Initializes an empty swarm and returns the tokens as a tuple.
    """
    subprocess.check_call(["docker", "swarm", "init"])
    manager_token = (
        subprocess.check_output(["docker", "swarm", "join-token", "-q", "manager"])
        .decode("utf-8")
        .strip()
    )

    worker_token = (
        subprocess.check_output(["docker", "swarm", "join-token", "-q", "worker"])
        .decode("utf-8")
        .strip()
    )
    return manager_token, worker_token


def instance_tags(instance):
    """
    Converts boto3 tags to a dict()
    """
    return {tag["Key"]: tag["Value"] for tag in instance.tags}


def get_running_instances():
    """
    Gets the running instances in a VPC as a set.
    """
    return {
        vpc_instance
        for vpc_instance in get_vpc().instances.all()
        if vpc_instance.state["Name"] == "running"
    }


class ManagerInstance:
    def __init__(self, instance, manager_token, worker_token):
        self.ip = instance.private_ip_address
        self.manager_token = manager_token
        self.worker_token = worker_token


class SwarmJoinError(RuntimeError):
    pass


def join_swarm_with_token(swarm_manager_ip, token):
    """
    Joins the swarm
    """
    logger.debug("join %s %s", swarm_manager_ip, token)
    try:
        subprocess.check_call(
            ["docker", "swarm", "join", "--token", token, swarm_manager_ip]
        )
    except subprocess.CalledProcessError as error:
        raise SwarmJoinError("Unable to join swarm") from error


def get_manager_instance_vpc_tags(exclude_self=False):
    instances_considered = get_running_instances()
    if exclude_self:
        instances_considered = filter(
            lambda vpc: vpc != get_current_instance(), instances_considered
        )
    for vpc_instance in instances_considered:
        vpc_instance_tags = instance_tags(instance=vpc_instance)
        if (
            vpc_instance_tags["Role"] == "manager"
            and vpc_instance_tags["ManagerJoinToken"]
            and vpc_instance_tags["WorkerJoinToken"]
        ):
            return ManagerInstance(
                vpc_instance,
                vpc_instance_tags["ManagerJoinToken"],
                vpc_instance_tags["WorkerJoinToken"],
            )

    return None


def update_tokens_vpc_tags(instance, manager_token, worker_token):
    instance.create_tags(
        Tags=[
            {"Key": "ManagerJoinToken", "Value": manager_token},
            {"Key": "WorkerJoinToken", "Value": worker_token},
        ]
    )
    logger.debug(
        "update %s %s %s", instance.private_ip_address, manager_token, worker_token
    )


def join_as_manager(get_manager_instance, update_tokens):
    def initialize_swarm_and_update_tokens():
        (manager_token, worker_token) = initialize_swarm()
        update_tokens(get_current_instance(), manager_token, worker_token)

    another_manager_instance = get_manager_instance(exclude_self=True)
    if another_manager_instance is None:
        for attempt in range(10 * instance_index):
            another_manager_instance = get_manager_instance(exclude_self=True)
            if another_manager_instance is None:
                logger.warning("Attempt #%d failed, retrying after sleep...", attempt)
                time.sleep(random.randint(5, 15))
            else:
                break

    if another_manager_instance is None:
        initialize_swarm_and_update_tokens()
    else:
        try:
            join_swarm_with_token(
                another_manager_instance.ip, another_manager_instance.manager_token
            )
            update_tokens(
                get_current_instance(),
                another_manager_instance.manager_token,
                another_manager_instance.worker_token,
            )
        except SwarmJoinError:
            # Unable to join the swarm, it may no longer be valid.  Create a new one.
            initialize_swarm_and_update_tokens()


def join_as_worker(get_manager_instance):
    manager_instance = None
    for attempt in range(100):
        manager_instance = get_manager_instance()
        if manager_instance is None:
            logger.warning("Attempt #%d failed, retrying after sleep...", attempt)
            time.sleep(random.randint(5, 15))
        else:
            break
    if manager_instance is None:
        raise SwarmJoinError("Unable to join swarm, no manager found")

    join_swarm_with_token(manager_instance.ip, manager_instance.worker_token)


def is_manager_role():
    return instance_tags(get_current_instance())["Role"] == "manager"


def get_vpc():
    mac_request = urllib.request.Request(
        "http://169.254.169.254/latest/meta-data/mac",
        headers={"X-aws-ec2-metadata-token": metadata_token},
    )
    mac = urllib.request.urlopen(mac_request).read().decode()
    vpc_id_request = urllib.request.Request(
        f"http://169.254.169.254/latest/meta-data/network/interfaces/macs/{mac}/vpc-id",
        headers={"X-aws-ec2-metadata-token": metadata_token},
    )
    vpc_id = urllib.request.urlopen(vpc_id_request).read().decode()
    return ec2.Vpc(vpc_id)


def get_current_instance():
    global _current_instance
    if _current_instance:
        return _current_instance
    _current_instance = ec2.Instance(instance_id)
    return _current_instance


def join_swarm():
    get_manager_instance = get_manager_instance_vpc_tags
    update_tokens = update_tokens_vpc_tags

    if is_manager_role():
        join_as_manager(get_manager_instance, update_tokens)
    else:
        join_as_worker(get_manager_instance)


def set_ssh_authorization_mode():
    if ssh_authorization_method == "ec2-instance-connect":
        subprocess.check_call(["yum", "install", "ec2-instance-connect"])
    elif ssh_authorization_method == "iam":
        sshd_config = []
        with open("/etc/ssh/sshd_config", mode="r") as sshd_config_file:
            for line in sshd_config_file:
                if not line.startswith(
                    "AuthorizedKeysCommand "
                ) and not line.startswith("AuthorizedKeysCommandUser "):
                    sshd_config.append(line)
        sshd_config.append(
            "AuthorizedKeysCommand /opt/iam-authorized-keys-command %u %f\n"
        )
        sshd_config.append("AuthorizedKeysCommandUser nobody\n")

        with open("/etc/ssh/sshd_config", mode="w") as sshd_config_file:
            sshd_config_file.writelines(sshd_config)
        subprocess.check_call(["systemctl", "restart", "sshd"])


def install_docker():
    subprocess.check_call(
        [
            "yum-config-manager",
            "--add-repo",
            "https://download.docker.com/linux/centos/docker-ce.repo",
        ]
    )
    subprocess.check_call(
        [
            "yum",
            "install",
            "docker-ce",
            "docker-ce-cli",
            "containerd.io",
            "docker-buildx-plugin",
            "docker-compose-plugin",
        ]
    )
    subprocess.check_call(["systemctl", "start", "docker"])


def tag_start():
    now = started_on.isoformat()
    get_current_instance().create_tags(
        Tags=[{"Key": "CloudInitStartedOn", "Value": now}]
    )


def tag_completion():
    now = datetime.now(timezone.utc)
    elapsed_seconds = int((now - started_on).total_seconds())
    get_current_instance().create_tags(
        Tags=[
            {
                "Key": "CloudInitCompletedOn",
                "Value": now.isoformat(),
            },
            {
                "Key": "CloudInitTime",
                "Value": str(elapsed_seconds),
            },
        ]
    )


# install_docker()
tag_start()
update_daemon_json()
initialize_system_daemons_and_hostname()
join_swarm()
# create_swap()
set_ssh_authorization_mode()
tag_completion()
