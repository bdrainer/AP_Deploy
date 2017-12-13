#!/usr/bin/env bash

./gen

dist/set-state-store.sh

kubectl create -f dist/k8s-iat-wiris.yml

kubectl create -f dist/k8s-iat.yml