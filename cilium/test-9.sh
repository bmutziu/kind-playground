kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: hubble-relay
  namespace: kube-system
specs:
  - nodeSelector:
      # apply to all nodes
      matchLabels: {}
    ingress:
    # hubble relay -> hubble agent
    - fromEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: hubble-relay
      toPorts:
      - ports:
        - port: '4244'
          protocol: TCP
    egress:
    # kubelet -> hubble relay probes
    - toEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: hubble-relay
      toPorts:
      - ports:
        - port: '4245'
          protocol: TCP
  - endpointSelector:
      # apply to hubble relay pods
      matchLabels:
        io.cilium.k8s.policy.serviceaccount: hubble-relay
    ingress:
    # kubelet -> hubble relay probes
    - fromEntities:
      - host
      toPorts:
      - ports:
        - port: '4245'
          protocol: TCP
    egress:
    # hubble relay -> hubble agent
    - toEntities:
      - host
      - remote-node
      toPorts:
      - ports:
        - port: '4244'
          protocol: TCP
    # hubble relay -> core dns
    - toEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: coredns
      toPorts:
      - ports:
        - port: '53'
          protocol: UDP
  - endpointSelector:
      # apply to core dns endpoints
      matchLabels:
        io.cilium.k8s.policy.serviceaccount: coredns
    ingress:
    # hubble relay -> core dns
    - fromEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: hubble-relay
      toPorts:
      - ports:
        - port: '53'
          protocol: UDP
EOF
