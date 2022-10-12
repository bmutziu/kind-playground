kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: core-dns-bis
  namespace: kube-system
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: coredns
  ingress:
  - fromEndpoints:
    - matchLabels:
        io.cilium.k8s.policy.serviceaccount: default
  egress:
  - toEntities:
    - kube-apiserver
EOF
