#!/bin/bash

./gen

dist/set-state-store.sh

kubectl create -f dist/k8s-efs-report-volume.yml

kubectl create -f dist/k8s-efs-report-volume-claim.yml

kubectl create -f dist/k8s-item-report-job.yml