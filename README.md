# Helm-chart for Flyte sandboxed core deployment

This helm-chart created for Flyte [Single Cluster Production-grade Cloud Deployment](https://docs.flyte.org/en/latest/deployment/deployment/cloud_production.html) without ingress, but with envoy proxy. It is useful if you need a personal Flyte instance without external access.

## Flyte deployment

### 1. Install helm dependencies
```
$ helm dependency build
```

### 2. Deploy Flyte
```
$ helm upgrade flyte . --install --create-namespace -n flyte
```

## Connect to Flyte from local workstation

1. Create hosts records
```
$ sudo vi /etc/hosts
127.0.0.1       minio.flyte.svc.cluster.local
```

2. Bind ports
```
$ export KUBECONFIG=$(pwd)/kubeconfig.yaml
$ kubectl -n flyte port-forward service/flyteproxy 8088:80
$ kubectl -n flyte port-forward service/minio 9000:9000
```

3. Create Flyte config
```
$ cat <<EOF > ~/.flyte/config.yaml
admin:
  endpoint: localhost:8088
  authType: Pkce
  insecure: true
console:
  endpoint: http://localhost:8088
logger:
  show-source: true
  level: 6
EOF
```

4. Check API
```
flytectl get execution -p flytesnacks -d development
```

5. Run hello_world_wf workflow
```
$ pyflyte run --remote ./examples/hello_world.py hello_world_wf
```
open execution returned http://localhost:8088/console/projects/flytesnacks/domains/development/executions/... link in browser

## Private Docker registry cases

### Deploy private docker registry in Kubernetes
This step can be skipped if you already have properly installed container registry. To install private docker registry in private Kubernetes you have to:
1. Generate self-signed certificates for Certificate Authority (CA)
2. Generate self-signed certificates for private Docker registry
3. Create kubernetes namespace and secret with docker registry key and certificate
4. Deploy private Docker registry helm-chart
5. Get ClusterIP of docker registry, test the deployment
6. Save self-signed CA certificates and add hosts record in all kubernetes nodes
7. Update certificate cache

### 1. Generate self-signed certificates for Certificate Authority (CA)
```
$ mkdir -p certs

# Generate a private key for the CA
$ docker run --rm --entrypoint openssl -v $(pwd)/certs:/certs alpine/openssl \
  genrsa 2048 > certs/myorg-ca-key.pem

# Generate certificate for CA
$ docker run --rm --entrypoint openssl -v $(pwd)/certs:/certs alpine/openssl \
  req -x509 -new -days 3650 -nodes -sha256 \
  -key certs/myorg-ca-key.pem -out certs/myorg-ca-cert.crt \
  -subj "/CN=MyOrg Root CA/O=MyOrg/OU=Datalake"
```

### 2. Generate self-signed certificates for private Docker registry
```
# Generate private container registry private key and certificate request
$ docker run --rm --entrypoint openssl -v $(pwd)/certs:/certs alpine/openssl \
  req -new -newkey rsa:4096 -days 3650 -nodes \
  -keyout certs/registry-key.pem -out certs/registry-req.csr \
  -subj "/CN=registry.docker-registry.svc.cluster.local/O=MyOrg/OU=Datalake" \
  -addext "subjectAltName=DNS:registry.docker-registry.svc.cluster.local"

# Generate private container registry certificate
$ docker run --rm --entrypoint openssl -v $(pwd)/certs:/certs alpine/openssl \
  x509 -req -days 3650 -CAcreateserial -copy_extensions copyall \
  -CA certs/myorg-ca-cert.crt -CAkey certs/myorg-ca-key.pem \
  -in certs/registry-req.csr -out certs/registry-cert.crt

# Check the certificate, X509v3 Subject Alternative Name should be defined
$ openssl x509 -text -noout -in certs/registry-cert.crt
# X509v3 extensions:
#    X509v3 Subject Alternative Name:
#        DNS:registry.docker-registry.svc.cluster.local
```

### 3. Create kubernetes namespace and secret with docker registry key and certificate
```
$ kubectl create namespace docker-registry

$ kubectl create secret generic secret-tls-docker-registry -n docker-registry \
    --from-file=tls.crt=./certs/registry-cert.crt \
    --from-file=tls.key=./certs/registry-key.pem
```

### 4. Deploy private Docker registry helm-chart
```
$ helm repo add twuni https://helm.twun.io

$ helm upgrade docker-registry twuni/docker-registry \
  --install --create-namespace -n docker-registry --version 2.2.3 \
  --set fullnameOverride=registry \
  --set persistence.enabled=true \
  --set service.type=ClusterIP \
  --set tlsSecretName=secret-tls-docker-registry
```

### 5. Get ClusterIP of docker registry, test the deployment
```
$ kubectl get service/registry -n docker-registry
NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
docker-registry   ClusterIP   10.21.116.XXX   <none>        5000/TCP   18h

# Bind docker registry port to localhost:5000
$ kubectl -n docker-registry port-forward service/registry 5000:5000

# Test availablity
$ curl -k https://localhost:5000/v2/_catalog
# {"repositories":[]}
```

### 6. Save self-signed CA certificates and add hosts record in all kubernetes nodes
```
# 5.1. Run this locally to get certificate create command
$ echo -e "cat <<EOF > /host/usr/local/share/ca-certificates/myorg-ca-cert.crt\n$(cat certs/myorg-ca-cert.crt)\nEOF"

it should be like
cat <<EOF > /host/usr/local/share/ca-certificates/myorg-ca-cert.crt
-----BEGIN CERTIFICATE-----
MIIDMzCCAhugAwIBAgIUMnK4JtFAsrpm5VHdj+muIXVTSBYwDQYJKoZIhvcNAQEL
...
++ksUbTXkw==
-----END CERTIFICATE-----
EOF

# Get all kubernetes nodes in cluster
$ kubectl get nodes

# For every Kubernetes node:

# Run debug container
$ kubectl debug -it --image=alpine node/<node-name>

# Run certificate saving command from 5.1. in debug container
cat <<EOF > /host/usr/local/share/ca-certificates/myorg-ca-cert.crt
-----BEGIN CERTIFICATE-----
MIIDMzCCAhugAwIBAgIUMnK4JtFAsrpm5VHdj+muIXVTSBYwDQYJKoZIhvcNAQEL
...
++ksUbTXkw==
-----END CERTIFICATE-----
EOF

# Add registry.docker-registry.svc.cluster.local to hosts file
$ echo "10.21.221.164       registry.docker-registry.svc.cluster.local" >> /host/etc/hosts
```

### 7. Update certificate cache
If you have ssh access to kubernates nodes, just run update-ca-certificates. If you are on managed cluster - reboot the nodes for certificate updates.

### Debug
```
$ kubectl run multitool --image=wbitt/network-multitool
```

## Connect to docker registry from local workstation

1. Create hosts records
```
$ sudo vi /etc/hosts
127.0.0.1       registry.docker-registry.svc.cluster.local
```

2. Bind docker registry ports
```
$ export KUBECONFIG=$(pwd)/kubeconfig.yaml
$ kubectl -n docker-registry port-forward service/registry 5000:5000
```

### Run custom_container workflow, in this example private docker registry is used
```
$ pyflyte run --remote ./examples/custom_container.py custom_container_wf
```
open execution returned http://localhost:8088/console/projects/flytesnacks/domains/development/executions/... link in browser

## Debugging Templates

[Helm manual](https://helm.sh/docs/chart_template_guide/debugging/)

```
helm upgrade flyte . --install --create-namespace -n flyte --dry-run --debug > generated_helm.yaml
```
