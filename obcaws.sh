#!/bin/bash

set -e

loglevel=0

log() {
	local level=$1
	shift
	local msg="$*"

	if [[ $loglevel -ge $level ]]; then
		echo "$0: $msg" >&2
	fi
}

usage() {
	echo "$0: usage: $0 [ -n namespace ] [ -r namespace/route ] [-v] [-h bucket_host]"
}

while getopts 'n:h:r:v' ch; do
	case $ch in
	(n)	namespace=$OPTARG;;
	(h)	bucket_host=$OPTARG;;
	(r)	bucket_host_route=$OPTARG;;
	(v)	loglevel=$(( loglevel + 1 ));;
	(--)	break;;
	(\?)	usage >& 2
		exit 1
		;;
	esac
done
shift $((OPTIND - 1))

obc=$1
api=$2
shift 2

if [[ -z $bucket_host ]] && [[ $bucket_host_route ]]; then
	bucket_host_ns=${bucket_host_route%/*}
	bucket_host_route=${bucket_host_route#*/}
	bucket_host=$(kubectl -n $bucket_host_ns \
		get route $bucket_host_route -o json |
		jq -r '.status.ingress[0].host')
fi

tempdir=$(mktemp -d .awsXXXXXX)
trap "rm -rf $tempdir" EXIT

log 1 "getting obc secret"
kubectl ${namespace:+-n $namespace} get secret $obc -o json > $tempdir/secret.json

log 1 "getting obc config"
kubectl ${namespace:+-n $namespace} get configmap $obc -o json > $tempdir/config.json

if [[ -z $bucket_host ]]; then
	bucket_host=$(jq -r .data.BUCKET_HOST $tempdir/config.json)
fi

bucket_name=$(jq -r .data.BUCKET_NAME $tempdir/config.json)
aws_access_key_id=$(jq -r '.data.AWS_ACCESS_KEY_ID|@base64d' $tempdir/secret.json)
aws_secret_access_key=$(jq -r '.data.AWS_SECRET_ACCESS_KEY|@base64d' $tempdir/secret.json)
endpoint=https://${bucket_host}

log 2 "bucket_host = $bucket_host"
log 2 "bucket_name = $bucket_name"
log 2 "endpoint = $endpoint"

cat >$tempdir/credentials <<EOF
[default]
AWS_ACCESS_KEY_ID=$aws_access_key_id
AWS_SECRET_ACCESS_KEY=$aws_secret_access_key
EOF

args=()
for arg in "$@"; do
	args+=(${arg//BUCKET/$bucket_name})
done

podman run --rm \
	-v $tempdir:/root/.aws \
	-v $PWD:$PWD -w $PWD \
	amazon/aws-cli $api --endpoint $endpoint "${args[@]}"
