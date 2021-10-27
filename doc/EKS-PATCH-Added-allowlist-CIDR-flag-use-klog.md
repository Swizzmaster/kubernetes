## What does it do

With this patch it is possible to have the API Server only establish proxy connections to a set of allow-listed IPs. Conversely, the API Server will refuse to perform a proxy operations to IPs in a CIDR that has not been allowed.

Via the `api/v1/namespaces/default/pods/<pod>:<container>:<port>/proxy/pods` endpoint, the API Server proxy TCP[1] connections from a client to any pod. To do so the API Server directly establish a connection with the pod by contacting the pod's IP address.

Note: the "/proxy" verb also exists for nodes and services. For nodes, the patch is 1 layer of defence, another is that apiserver does tls server authentication with kubelets (whose certificates must be signed by our eks-signer).
For services, another layer is that apiserver validation prevents Endpoints from being created with bad IPs.

[1] Ticket to track UDP support: https://github.com/kubernetes/kubernetes/issues/47862

## Why do we need it

There is a race where an actor override a pod's IP to `127.0.0.1` or `0.0.0.0` and then asks the API Server to establish a proxy connection with that pod. When the actor wins the race, the API Server (running on the master node)
will proxy connection to other services running on that same master node.

This means the actor now gets access to services that we do not want exposed to customers.

In order to prevent this from happening, we add a `--proxy-cidr-allowlist` option to the API Server. We set the CIDR list to the customer's subnets CIDR, effectively preventing the API Server from proxying with services running on localhost.


## How to reproduce

```
# Terminal 1:
kubectl proxy

# Terminal 2:
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: fake-pod
  finalizers:
  - kubernetes
spec:
  nodeName: some.fake.node
  containers:
  - image: nginx
    name: nginx
    ports:
    - containerPort: 80
EOF

# Force pod ip to 0.0.0.0
curl -k -XPATCH \
    -H "Content-Type: application/json-patch+json" \
    --data '[{"op": "add", "path": "/status/phase", "value": "Running"},{"op": "add", "path": "/status/podIP", "value": "0.0.0.0"}]' \
    http://127.0.0.1:8001/api/v1/namespaces/default/pods/fake-pod/status

# Proxy to kubelet running on API Server
curl -k -XGET \
    -H "Content-Type: application/json-patch+json" \
    -H "Accept: application/json" \
    http://127.0.0.1:8001/api/v1/namespaces/default/pods/https:fake-pod:10250/proxy/pods
```
