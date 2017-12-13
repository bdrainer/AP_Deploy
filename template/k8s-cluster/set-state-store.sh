#!/bin/bash

kops export kubecfg --state s3://@AWS_STATE_STORE_NAME@ --name @K8S_CLUSTER_NAME@