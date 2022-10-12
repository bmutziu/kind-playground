kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: ingress-nginx-controller-hc
  namespace: ingress-nginx
specs:
  - nodeSelector:
      # apply to all nodes
      matchLabels: {}
    egress:
    # kubelet -> ingress-nginx probes
    - toEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: ingress-nginx
      toPorts:
      - ports:
        - port: '10254'
          protocol: TCP
  - endpointSelector:
      # apply to metallb pods
      matchLabels:
        io.cilium.k8s.policy.serviceaccount: ingress-nginx
    ingress:
    # kubelet -> ingress-nginx probes
    - fromEntities:
      - host
      toPorts:
      - ports:
        - port: '10254'
          protocol: TCP
    egress:
    # ingress-nginx -> api server
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
    # ingress-nginx -> api server
    - fromEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: metallb-controller
      toPorts:
      - ports:
        - port: '6443'
          protocol: TCP
EOF
