#!/usr/bin/env python
from botocore.exceptions import NoCredentialsError
import boto3
import simplejson as json
import logging
import os
import os.path
import random
import stat
import subprocess
import time
import urllib2
import zipfile

DAEMON_JSON = "/etc/docker/daemon.json"
logger = logging.getLogger(__name__)
logging.basicConfig(level=os.environ.get("LOGLEVEL", "WARNING"))

# Set values loaded by the template
store_join_tokens_as_tags = bool('${store_join_tokens_as_tags}')
instance_index = int('${instance_index}')
s3_bucket = '${s3_bucket}'
vpc_name = '${vpc_name}'
group = '${group}'
cloudwatch_log_group = '${cloudwatch_log_group}'

# Global cached results
_current_instance = None

# Extract metadata
instance_identity = json.load(urllib2.urlopen('http://169.254.169.254/latest/dynamic/instance-identity/document'))
instance_id = instance_identity['instanceId']
region_name = instance_identity['region']

# AWS resources
ec2 = boto3.resource('ec2', region_name=region_name)
s3 = boto3.resource('s3', region_name=region_name)

def configure_logging():
    """
    Updates daemon.json to enable AWS Cloudwatch logging
    """
    if cloudwatch_log_group == "":
        return

    if os.path.exists(DAEMON_JSON):
        daemon_json = json.load(DAEMON_JSON)
    else:
        daemon_json = json.loads("{}")

    daemon_json["log-driver"] = "awslogs"
    daemon_json["log-opts"] = {
        "awslogs-group" : cloudwatch_log_group,
        "tag": "{{.Name}}"
    }

    f = open(DAEMON_JSON, "w")
    f.write(json.dumps(daemon_json))
    f.close()


def initialize_system_daemons_and_hostname():
    """
    Load system daemons and host name
    """
    subprocess.check_call(["systemctl", "daemon-reload"])
    subprocess.check_call(["systemctl", "enable", "docker.service"])
    subprocess.check_call(["systemctl", "start", "docker.service"])

    list_unit_files = subprocess.check_output(["systemctl", "list-unit-files"])
    if "yum-cron.service" in list_unit_files:
        subprocess.check_call(["systemctl", "enable", "yum-cron"])
        subprocess.check_call(["systemctl", "start", "yum-cron"])
    if "haveged.service" in list_unit_files:
        subprocess.check_call(["systemctl", "enable", "haveged"])
        subprocess.check_call(["systemctl", "start", "haveged"])

    subprocess.check_call(["hostnamectl", "set-hostname",
        "%s%d-%s" % (group, instance_index, vpc_name)])

def create_swap():
    """
    Initializes and registeres the swap volume
    """
    subprocess.check_output(["mkswap", "/dev/xvdf"])
    f = open("/etc/fstab", "a")
    f.write("/dev/xvdf none swap defaults 0 0\n")
    f.close()
    subprocess.check_output(["swapon", "-a"])

def initialize_swarm():
    """
    Initializes an empty swarm and returns the tokens as a tuple.
    """
    subprocess.check_call(["docker", "swarm", "init"])
    manager_token = subprocess.check_output(
        ["docker", "swarm", "join-token", "-q", "manager"]).strip()

    worker_token = subprocess.check_output(
        ["docker", "swarm", "join-token", "-q", "worker"]).strip()
    return (manager_token, worker_token)

def instance_tags(instance):
    """
    Converts boto3 tags to a dict()
    """
    return {tag['Key']: tag['Value'] for tag in instance.tags}

def get_running_instances():
    """
    Gets the running instances in a VPC as a set.
    """
    return { vpc_instance for vpc_instance in get_vpc().instances.all() if vpc_instance.state['Name'] == 'running' }

class ManagerInstance:
    def __init__(self, instance, manager_token, worker_token):
        self.ip = instance.private_ip_address
        self.manager_token = manager_token
        self.worker_token = worker_token

def join_swarm_with_token(swarm_manager_ip, token):
    """
    Joins the swarm
    """
    logging.debug("join %s %s", swarm_manager_ip, token)
    subprocess.check_call(
        ["docker", "swarm", "join", "--token", token, swarm_manager_ip])


def get_manager_instance_vpc_tags(exclude_self=False):
    instances_considered = get_running_instances()
    if exclude_self:
        instances_considered = filter(lambda vpc_instance: vpc_instance != get_current_instance(), instances_considered)
    for vpc_instance in instances_considered:
        vpc_instance_tags = instance_tags(instance=vpc_instance)
        if vpc_instance_tags['Role'] == 'manager' and vpc_instance_tags['ManagerJoinToken'] and vpc_instance_tags['WorkerJoinToken']:
            return ManagerInstance(
                vpc_instance,
                vpc_instance_tags['ManagerJoinToken'],
                vpc_instance_tags['WorkerJoinToken'])

    return None

def get_manager_instance_s3(exclude_self=False):

    def get_object_from_s3(name):
        """
        Gets an object from S3, returns None for any error
        """
        try:
            object = s3.Object(s3_bucket, name)
            return object.get()['Body'].read()
        except:
            return None

    manager_token = get_object_from_s3("manager_token")
    worker_token = get_object_from_s3("worker_token")
    manager0_ip = get_object_from_s3("ip0")
    manager1_ip = get_object_from_s3("ip1")

    # Find the manager instance to use
    manager_instance = None
    instances_considered = get_running_instances()
    if exclude_self:
        instances_considered = filter(lambda vpc_instance: vpc_instance != get_current_instance(), instances_considered)
    for vpc_instance in instances_considered:
        if vpc_instance.private_ip_address == manager0_ip or vpc_instance.private_ip_address == manager1_ip:
            manager_instance = vpc_instance

    if manager_instance and manager_token and worker_token:
        return ManagerInstance(
            manager_instance,
            manager_token,
            worker_token)
    else:
        logger.warning("Unable to locate manager manager_token=%s worker_token=%s manager0_ip=%s manager1_ip=%s", manager_token, worker_token, manager0_ip, manager1_ip)
        return None


def update_tokens_vpc_tags(instance, manager_token, worker_token):
    instance.create_tags(
        Tags=[
            {
                "Key": "ManagerJoinToken",
                "Value": manager_token
            },
            {
                "Key": "WorkerJoinToken",
                "Value": worker_token
            }
        ]
    )
    logger.debug("update %s %s %s", instance.private_ip_address, manager_token, worker_token)

def update_tokens_s3(instance, manager_token, worker_token):
    manager_token_object = s3.Object(s3_bucket, 'manager_token')
    manager_token_object.put(Body=bytes(manager_token),
                             StorageClass="ONEZONE_IA")
    worker_token_object = s3.Object(s3_bucket, 'worker_token')
    worker_token_object.put(Body=bytes(worker_token),
                            StorageClass="ONEZONE_IA")
    myip_object = s3.Object(s3_bucket, 'ip%d' % instance_index)
    myip_object.put(Body=bytes(instance.private_ip_address), StorageClass="ONEZONE_IA")

def join_as_manager(get_manager_instance, update_tokens):
    def initialize_swarm_and_update_tokens():
        (manager_token, worker_token) = initialize_swarm()
        update_tokens(get_current_instance(), manager_token, worker_token)

    another_manager_instance = None
    for attempt in range(10 * instance_index):
        another_manager_instance = get_manager_instance(exclude_self=True)
        if another_manager_instance == None:
            logger.warning("Attempt #%d failed, retrying after sleep...", attempt)
            time.sleep(random.randint(5,15))
        else:
            break

    if another_manager_instance == None:
        initialize_swarm_and_update_tokens()
    else:
        try:
            join_swarm_with_token(another_manager_instance.ip, another_manager_instance.manager_token)
            update_tokens(get_current_instance(), another_manager_instance.manager_token, another_manager_instance.worker_token)
        except:
            # Unable to join the swarm, it may no longer be valid.  Create a new one.
            initialize_swarm_and_update_tokens()

def join_as_worker(get_manager_instance):
    manager_instance = None
    for attempt in range(100):
        manager_instance = get_manager_instance()
        if manager_instance == None:
            logger.warning("Attempt #%d failed, retrying after sleep...", attempt)
            time.sleep(random.randint(5,15))
        else:
            break
    if manager_instance == None:
        raise Exception("Unable to join swarm, no manager found")

    join_swarm_with_token(manager_instance.ip, manager_instance.worker_token)

def is_manager_role():
    return instance_tags(get_current_instance())['Role'] == 'manager'

def get_vpc():
    mac = urllib2.urlopen('http://169.254.169.254/latest/meta-data/mac').read().decode()
    vpc_id = urllib2.urlopen('http://169.254.169.254/latest/meta-data/network/interfaces/macs/%s/vpc-id' % mac).read().decode()
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

    if not store_join_tokens_as_tags:
        # Set function points to S3 version
        try:
            bucket = s3.Bucket(s3_bucket)
            bucket.objects.all()
        except NoCredentialsError as e:
            time.sleep(5)
        get_manager_instance = get_manager_instance_s3
        update_tokens = update_tokens_s3

    if is_manager_role():
        join_as_manager(get_manager_instance, update_tokens)
    else:
        join_as_worker(get_manager_instance)

def install_monitoring_tools():

    """
    As documented in https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/mon-scripts.html
    """

    scripts_zip_path = "/tmp/CloudWatchMonitoringScripts.zip"
    crontab_path = "/tmp/aws-scripts-mon.crontab"
    scripts_zip = urllib2.urlopen('https://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.2.zip').read()
    scripts_zip_file = open(scripts_zip_path, 'wb')
    scripts_zip_file.write(scripts_zip)
    scripts_zip_file.close()

    zipfile.ZipFile(scripts_zip_path, 'r').extractall("/root")

    with open(crontab_path, 'w') as f:
        try:
            crontab = subprocess.check_output(['crontab', '-l']).decode()
            crontab += "\n"
        except subprocess.CalledProcessError:
            crontab = ""
        crontab += "*/5 * * * * /root/aws-scripts-mon/mon-put-instance-data.pl "
        crontab += "--mem-used-incl-cache-buff "
        crontab += "--mem-util "
        crontab += "--mem-used "
        crontab += "--swap-util "
        crontab += "--swap-used "
        crontab += "--disk-space-util "
        crontab += "--disk-space-avail "
        crontab += "--disk-space-used "
        crontab += "--disk-path=/ "
        crontab += "--from-cron"
        crontab += "\n"
        f.write(crontab)
        f.close()
    subprocess.check_call(["crontab", crontab_path])
    os.remove(crontab_path)
    os.remove(scripts_zip_path)
    os.chmod("/root/aws-scripts-mon/mon-put-instance-data.pl", stat.S_IRWXU)

configure_logging()
initialize_system_daemons_and_hostname()
join_swarm()
create_swap()
install_monitoring_tools()
