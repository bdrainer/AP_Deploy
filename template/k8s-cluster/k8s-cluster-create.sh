#!/bin/bash
#
# Creates a Kubernetes cluster configuration using kops and stores it in the AWS S3 state store.  The cluster is then
# created in AWS.
#
# A new VPC is created in AWS as a result of using this configuration.
#

kops create cluster \
    --node-count 4 \
    --zones @K8S_NODE_ZONE@ \
    --master-zones @K8S_NODE_ZONE@ \
    --dns-zone @K8S_DNS_ZONE@ \
    --node-size @K8S_NODE_SIZE@ \
    --master-size @K8S_NODE_SIZE@ \
    --state s3://@AWS_STATE_STORE_NAME@ \
    --name @K8S_CLUSTER_NAME@ \
    --yes


