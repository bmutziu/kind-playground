kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: untitled-policy
specs:
  - endpointSelector:
      # apply to all nodes
      matchLabels:
        reserved:host: ''
    egress:
    - toEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: coredns
      toPorts:
      - ports:
        - port: '53'
          protocol: UDP
  - endpointSelector:
      matchLabels:
        io.cilium.k8s.policy.serviceaccount: coredns
    ingress:
    - fromEndpoints:
      - matchLabels:
          reserved:host: ''
      toPorts:
      - ports:
        - port: '53'
          protocol: UDP
  - endpointSelector:
      matchLabels:
        run: debug
    ingress:
    - fromEntities:
      - cluster
    egress:
    - toEntities:
      - cluster
    - toEndpoints:
      - matchLabels:
          io.kubernetes.pod.namespace: kube-system
          k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
          rules:
            dns:
              - matchPattern: "*"
    - toEntities:
        - world
EOF
