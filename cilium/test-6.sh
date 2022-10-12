kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: cert-manager-webhook
  namespace: cert-manager 
specs:
  - nodeSelector:
      # apply to all nodes
      matchLabels: {}
    egress:
    # kubelet -> cert-manager-webhook probes
    - toEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: cert-manager-webhook
      toPorts:
      - ports:
        - port: '6080'
          protocol: TCP
  - endpointSelector:
      # apply to cert-manager-webhook pods
      matchLabels:
        io.cilium.k8s.policy.serviceaccount: cert-manager-webhook
    ingress:
    # kubelet -> cert-manager-webhook probes
    - fromEntities:
      - host
      toPorts:
      - ports:
        - port: '6080'
          protocol: TCP
    egress:
    # cert-manager-webhook -> api server
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
    # cert-manager-webhook -> api server
    - fromEndpoints:
      - matchLabels:
          io.cilium.k8s.policy.serviceaccount: cert-manager-webhook
      toPorts:
      - ports:
        - port: '6443'
          protocol: TCP
EOF
