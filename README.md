# Keycloak-Infinispan

This is an implementation of [Keycloak IAM](https://www.keycloak.org/) with (remote) Infinispan caching system for a local Kubernetes cluster. This solution uses a combination of available Helm charts and Kubernetes yaml files for deployment.

## Prerequisites

- Minikube (https://minikube.sigs.k8s.io/docs/start/)
- Helm (https://helm.sh/docs/intro/quickstart/)
- Kubectl (https://kubernetes.io/docs/reference/kubectl/)

## Helm charts

- Bitnami PotgreSQL-HA (https://github.com/bitnami/charts/tree/main/bitnami/postgresql-ha)
- Infinispan Server (https://github.com/infinispan/infinispan-helm-charts)

## Keycloak YAML files

- keycloak.yaml (Keycloak deployment)
- keycloak-ingress.yaml (Ingress deployment for Keycloak)

# Setup

First we need to start minikube and enable the ingress addon:

```
minikube start
minikube addons enable ingress
```
Before deploying Keycloak we need to create our PosgreSQL database and start the Infinispan cluster for the distributed Keycloak cache.

```
# Prerequisites

# Adding Helm repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add openshift-helm-charts https://charts.openshift.io/

# Creating namespaces

# For Keycloak and PostgreSQL
kubectl create ns keycloak

# For the remote Infinispan server
kubectl create ns infinispan
```
## PosgreSQL-HA

Installing PosgreSQL-HA database in the keycloak namespace with one replica set (to make it easier to scale up later)

```
helm install -n keycloak postgre-db bitnami/postgresql-ha --set postgresql.replicaCount=1 --version 13.4.5
```
## Infinispan server

We are going to install Infinispan with the official Helm chart but using a modified values.yaml file that you can find in this repository. Some of the notable changes are creating the custom user in the security.batch section and creating a distributed cache ("sessions") on startup with the following details:

```
distributedCache:
  name: "sessions"
  mode: "SYNC"
  owners: "1"
  segments: "256"
  capacityFactor: "1.0"
  statistics: "false"
  encoding:
    mediaType: "application/x-jboss-marshalling"
  security:
  . authorization:
      enabled: "true"
     . roles:
        - "admin"
        - "application"
  expiration:
    lifespan: "5000"
    maxIdle: "1000"
  memory:
    maxCount: "100000"
    whenFull: "REMOVE"
  partitionHandling:
    whenSplit: "ALLOW_READ_WRITES"
    mergePolicy: "PREFERRED_NON_NULL"
```

To install:

```
helm install -n infinispan infinispan openshift-helm-charts/infinispan-infinispan --values infinispan-values.yaml --version 0.3.2
```

## Keycloak

We are going to use a self-signed certificate for this example deployment which you can create the following way and then create a secret in Kubernetes:

```
# Creating a TLS certificate
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout kc-tls.key -out kc-tls.crt -subj "/CN=kc.localtest.me/O=kc"

# Deploying to Kubernetes to use for the Ingress service
kubectl create secret -n keycloak tls kc-tls-secret --key kc-tls.key --cert kc-tls.crt
```
After that we can deploy keycloak and keycloak-ingress from this repository:

```
kubectl apply -n keycloak -f keycloak.yaml

kubectl apply -n keycloak -f keycloak-ingress.yaml
```
You can find the remote-cache ("sessions") configuration for Infinispan in the keycloak.yaml file in the kcb-infinispan-cache-config ConfigMap.

To be able to access Infinispan and Keycloak from your browser you can enable Minikube tunnel and port-forwarding:

```
# Port forwarding for Minikube
kubectl -n infinispan port-forward pod/infinispan-0 11222:11222

# Enable minikube tunnel
minikube tunnel
```
With this setup Keycloak admin console should be available from:
https://kc.localtest.me/

And Infinispan Server console:
http://0.0.0.0:11222/console/

## Deleting the deployments

```
# Keycloak
kubectl delete service keycloak -n keycloak
kubectl delete ingress keycloak-ingress -n keycloak
kubectl delete deployment keycloak -n keycloak
kubectl delete secret kc-tls-secret -n keycloak

# Infinispan
helm uninstall -n infinispan infinispan
kubectl delete -n infinispan secret infinispan-generated-secret
kubectl delete -n infinispan pvc data-volume-infinispan-0

# PostgreSQL database
helm uninstall -n keycloak postgre-db
kubectl delete -n keycloak pvc data-postgre-db-postgresql-ha-postgresql-0
```
