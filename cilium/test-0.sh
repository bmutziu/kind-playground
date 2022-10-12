kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: hubble-ui
  namespace: kube-system
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: hubble-ui
  egress:
  - toEntities:
    - kube-apiserver
  - toEndpoints:
    - matchLabels:
        io.cilium.k8s.policy.serviceaccount: hubble-relay
    - matchLabels:
        io.cilium.k8s.policy.serviceaccount: coredns
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: core-dns
  namespace: kube-system
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: coredns
  ingress:
  - fromEndpoints:
    - matchLabels:
        io.cilium.k8s.policy.serviceaccount: hubble-ui
    - matchLabels:
        io.cilium.k8s.policy.serviceaccount: hubble-relay
  egress:
  - toEntities:
    - kube-apiserver
    - world
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: hubble-relay
  namespace: kube-system
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: hubble-relay
  ingress:
  - fromEndpoints:
    - matchLabels:
        io.cilium.k8s.policy.serviceaccount: hubble-ui
  egress:
  - toEntities:
    - host
    - remote-node
  - toEndpoints:
    - matchLabels:
        io.cilium.k8s.policy.serviceaccount: coredns  
EOF
