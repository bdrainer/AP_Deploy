#!/bin/bash

./gen

dist/set-state-store.sh

kubectl create -f dist/k8s-config-service.yml
