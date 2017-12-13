#!/usr/bin/env bash

./gen

dist/set-state-store.sh

kubectl create -f dist/k8s-iat-ivs.yml