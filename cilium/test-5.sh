kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: ingress-nginx-defaultbackend-hc
  namespace: ingress-nginx
specs:
  - nodeSelector:
      # apply to all nodes
      matchLabels: {}
    egress:
    # kubelet -> ingress-nginx-defaultbackend probes
    - toEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: ingress-nginx-backend
      toPorts:
      - ports:
        - port: '8080'
          protocol: TCP
  - endpointSelector:
      # apply to ingress-nginx-defaultbackend pods
      matchLabels:
        io.cilium.k8s.policy.serviceaccount: ingress-nginx-backend
    ingress:
    # kubelet -> ingress-nginx-defaultbackend probes
    - fromEntities:
      - host
      toPorts:
      - ports:
        - port: '8080'
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
    # ingress-nginx-defaultbackend -> api server
    - fromEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: ingress-nginx-backend 
      toPorts:
      - ports:
        - port: '6443'
          protocol: TCP
EOF
