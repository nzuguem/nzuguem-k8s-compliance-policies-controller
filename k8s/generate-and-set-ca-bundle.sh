#!/bin/sh

SAN_DNS=$1
CERT_DEST_PATH=$2
WEBHOOK_MANIFEST=$3

openssl req -x509 -newkey rsa:2048 -keyout $CERT_DEST_PATH/nzuguem-compliance-policies-controller.key \
            -out $CERT_DEST_PATH/nzuguem-compliance-policies-controller.crt -days 3650 -nodes -subj "/O=nzuguem" \
            -addext "subjectAltName = DNS:$SAN_DNS"

export CA_BUNDLE=$(cat $CERT_DEST_PATH/nzuguem-compliance-policies-controller.crt | base64)

yq e -i '.webhooks[].clientConfig.caBundle = env(CA_BUNDLE)' k8s/nzuguem-k8s-compliance-policies-mutating-$WEBHOOK_MANIFEST.yml
yq e -i '.webhooks[].clientConfig.caBundle = env(CA_BUNDLE)' k8s/nzuguem-k8s-compliance-policies-validating-$WEBHOOK_MANIFEST.yml
