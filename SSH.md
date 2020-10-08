# IAM SSH Authentication

By default, there are no users defined by the module.  The `cloud_config_extra` allows by adding users using the cloud-init method.  For the IAM to work.  The `ssh_authorization_method` must be set to IAM and one or more IAM users is added via `ssh_users`.

## Adding the SSH public key

In the following examples, the IAM user is called `docker-user`.  *NOTE* `docker` cannot be used as the user name as it would cause problems with cloud-init as the `docker` group would exist and crash on creating the user.
 
To update the SSH public key to an existing user, use the CLI as follows:

```
aws iam upload-ssh-public-key --user-name docker-user --ssh-public-key-body "ssh-rsa AA... id_rsa"
```

## Defining the users

cloud-init uses the data pointed to by `cloud_config_extra` to add users.  The following are  is an example configuration file with two users: an admin and a normal docker daemon user.  The `docker-admin` account is part of the `wheel` group that will allow the user to access the shell directly, without the `wheel` group, the user will be limited to using `docker context` to access the server. 

```yaml
#cloud-config
users:
- name: docker-admin
  groups:
  - wheel
  - docker
  sudo: ['ALL=(ALL) NOPASSWD:ALL']
- name: docker-user
  groups:
  - docker
```

## Limitations

The current implementation supports a maximum of 100 keys per IAM user.  Although the AWS API may return less than that limit.
