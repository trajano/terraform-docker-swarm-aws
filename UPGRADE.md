# Upgrade notes

## 3.x to 4.x

* Do not enable `store_join_tokens_as_tags` as that will corrupt the cluster.
* `daemon_ssh=false` and `daemon_tls=true` will keep the same behaviour, but it is recommended that the defaults are used for for new clusters.

## 4.0.x to 4.1.x

* If packages are customized, `haveged` is now required.
