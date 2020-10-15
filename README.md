# OBCAWS

A wrapper script for running `aws-cli` commands against object buckets in
[OpenShift Container Storage][ocs] (OCS).

[ocs]: https://www.redhat.com/en/technologies/cloud-computing/openshift-container-storage

## Requirements

- This script uses `podman` to run the `amazon/aws-cli` image, so you'll need
  to have [podman][] installed.

- We use [jq][] for parsing JSON output from `kubectl get ...`. You'll need
  something relatively recent (at least 1.6) because we make use of the
  `base64d` filter to decode base64-encoded data.

[podman]: https://podman.io/
[jq]: https://stedolan.github.io/jq/

## Usage

```
obcaws: usage: obcaws [ -n namespace ] [ -r namespace/route ]
  [-v] [-h bucket_host]
```

For example, if I want to list objects in the bucket associated with my
`images` `ObjectBucketClaim` in my current namespace, using the external route
provided by the `s3` route in the `openshift-storage` namespace, I can run:

```
obsaws -r openshift-storage/s3 images s3 ls BUCKET
```

The token `BUCKET` will be replaced with the bucket name from the `OBC`.
The above command will get translated into something like:

```
podman run --rm \
  -v .awsoRs3VH:/root/.aws \
  -v $PWD:$PWD -w $PWD \
  amazon/aws-cli s3 --endpoint https://s3-openshift-storage.apps.example.com \
  ls images-eb819852-3a1f-4be3-96ec-eada6b6327eb
```

The first volume option in this command line (`-v .awsoRs3VH:/root/.aws`)
contains AWS-style credentials extracted from the secret that is associated
with your `OBC` resource.

The second volume option exposes `$PWD` on the host as `$PWD` inside the
container,  and sets the current working directory to that directory. This
means you can only access files/directories that are contained in `$PWD`.
