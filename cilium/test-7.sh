kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: cert-manager-cainjector
  namespace: cert-manager 
specs:
  - endpointSelector:
      # apply to cert-manager-cainjector pods
      matchLabels:
        io.cilium.k8s.policy.serviceaccount: cert-manager-cainjector
    egress:
    # cert-manager-cainjector -> api server
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
    # cert-manager-cainjector -> api server
    - fromEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: cert-manager-cainjector
      toPorts:
      - ports:
        - port: '6443'
          protocol: TCP
EOF
