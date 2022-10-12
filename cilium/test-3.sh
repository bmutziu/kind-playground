kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: metallb-controller-hc
  namespace: metallb-system
specs:
  - nodeSelector:
      # apply to all nodes
      matchLabels: {}
    egress:
    # kubelet -> metallb probes
    - toEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: metallb-controller
      toPorts:
      - ports:
        - port: '7472'
          protocol: TCP
  - endpointSelector:
      # apply to metallb pods
      matchLabels:
        io.cilium.k8s.policy.serviceaccount: metallb-controller
    ingress:
    # kubelet -> metallb probes
    - fromEntities:
      - host
      toPorts:
      - ports:
        - port: '7472'
          protocol: TCP
    egress:
    # metallb-controller -> api server
    - toEntities:
      - kube-apiserver
      toPorts:
      - ports:
        - port: '6443'
          protocol: TCP
  - nodeSelector:
      # apply to master nodes
      matchLabels:
        node-role.kubernetes.io/control-plane: ''
    ingress:
    # metallb-controller -> api server
    - fromEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: metallb-controller
      toPorts:
      - ports:
        - port: '6443'
          protocol: TCP
EOF
