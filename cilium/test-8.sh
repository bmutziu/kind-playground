kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: cert-manager
  namespace: cert-manager 
specs:
  - endpointSelector:
      # apply to cert-manager pods
      matchLabels:
        io.cilium.k8s.policy.serviceaccount: cert-manager
    egress:
    # cert-manager -> api server
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
    # cert-manager -> api server
    - fromEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: cert-manager
      toPorts:
      - ports:
        - port: '6443'
          protocol: TCP
EOF
