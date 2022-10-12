kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: netshoot
  namespace: default
specs:
  - endpointSelector:
      # apply to netshoot pods
      matchLabels:
        io.cilium.k8s.policy.serviceaccount: default
    egress:
    - toEntities:
        - world
EOF
