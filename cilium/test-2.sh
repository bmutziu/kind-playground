kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: cilium-metallb-udp
spec:
  nodeSelector:
    # apply to all nodes
    matchLabels: {}
  ingress:
  # node -> metallb
  - fromEntities:
    - remote-node
    toPorts:
    - ports:
      - port: '7946'
        protocol: UDP
  egress:
  # node -> metallb
  - toEntities:
    - remote-node
    toPorts:
    - ports:
      - port: '7946'
        protocol: UDP
EOF
