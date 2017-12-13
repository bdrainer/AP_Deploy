#!/bin/bash

./gen

dist/set-state-store.sh

kubectl create -f dist/k8s-ims.yml