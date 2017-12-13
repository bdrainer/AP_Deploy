#!/usr/bin/env bash

./gen

dist/set-state-store.sh

kubectl create -f dist/k8s-efs-volume.yml

kubectl create -f dist/k8s-efs-volume-claim.yml

kubectl create -f dist/k8s-ivs.yml