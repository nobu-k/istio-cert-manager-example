#!/bin/bash

set -euxo pipefail

if [[ ! -e ./ngrok-auth-token ]]; then
    2>1 echo 'ngrok-auth-token file must be provided'
    exit 1
fi

CLUSTER=istio-acme
k3d cluster create $CLUSTER --wait \
    --kubeconfig-update-default=false \
    --kubeconfig-switch-context=false \
    --k3s-server-arg \
    --disable=traefik \
    -p "8280:80@loadbalancer" -p "8281:443@loadbalancer"

export KUBECONFIG=$(k3d kubeconfig write $CLUSTER)
kubectl label namespace default istio-injection=enabled
kubectl apply -f namespaces
helm upgrade -i kubed appscode/kubed -n kube-system

kubectl apply -k "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v0.3.0"
istioctl install --set profile=demo -y
helm upgrade -i -f values/cert-manager.yaml -n cert-manager cert-manager jetstack/cert-manager

kubectl create secret generic ngrok-auth-token --from-file=token=./ngrok-auth-token

kubectl apply -k manifests
