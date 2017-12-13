#!/bin/bash

./gen

dist/set-state-store.sh

kubectl create -f dist/k8s-nginx-ingress.yml

kubectl create -f dist/k8s-cluster-autoscaler.yml
