#!/usr/bin/env bash

set -e

# CONSTANTS

readonly DNSMASQ_DOMAIN=kind.cluster

# FUNCTIONS

# init
function pause(){
   read -p "$*"
}

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

get_subnet(){
  docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' $1
}

subnet_to_ip(){
  echo $1 | sed "s@0.0/16@$2@"
}

cleanup(){
  log "CLEANUP ..."

  rm -rf .gitops
}

init(){
  log "INIT ..."

  mkdir .gitops
  touch .gitops/README.md
  git config --global init.defaultBranch main
  git init .gitops
  git -C .gitops config pull.rebase true
  git -C .gitops checkout -b main
  git -C .gitops add README.md
  git -C .gitops commit -m "first commit"
  git -C .gitops remote add origin http://gitea_admin:r8sA8CPHD9!bt6d@gitea.kind.cluster/gitea_admin/gitops.git
  git -C .gitops fetch --all || true
  git -C .gitops pull origin main || true
  git -C .gitops push -u origin main
}

install(){
  log "INSTALL ..."

  rm -rf .gitops/helm
  cp -r helm/ .gitops/

  cat <<EOF > .gitops/config.yaml
prometheus:
  operator:
    enabled: false

dns:
  private: $DNSMASQ_DOMAIN

metallb:
  start: $METALLB_START
  end: $METALLB_END

applications:
  argocd:
    enabled: false
  certManager:
    enabled: false
  cilium:
    enabled: false
  gitea:
    enabled: false
  metallb:
    enabled: false
  ingressNginx:
    enabled: false
  keycloak:
    enabled: false
  kubeview:
    enabled: false
  kyverno:
    enabled: false
  kyvernoPolicies:
    enabled: false
  metricsServer:                        
    enabled: true
  nodeProblemDetector:
    enabled: false
  policyReporter:
    enabled: false
  rbacManager:
    enabled: false
  polaris:
    enabled: false
  istio:
    enabled: false
  localPathProvisioner:
    enabled: false
EOF
}

push(){
  log "PUSH ..."

  cp .gitops/config.yaml .gitops/gitops/values.yaml

  git -C .gitops add .
  git -C .gitops commit -m "gitops" --allow-empty
  git -C .gitops push -u origin main
}

bootstrap(){
  log "BOOTSTRAP ..."

  local KIND_SUBNET=$(get_subnet kind)
  local METALLB_START=$(subnet_to_ip $KIND_SUBNET 255.200)
  local METALLB_END=$(subnet_to_ip $KIND_SUBNET 255.250)

  kubectl apply -n argocd -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gitops
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: http://gitea.kind.cluster/gitea_admin/gitops
    path: gitops
    targetRevision: HEAD
    helm:
      values: |
        prometheus:
          operator:
            enabled: false
        dns:
          private: $DNSMASQ_DOMAIN
        metallb:
          start: $METALLB_START
          end: $METALLB_END
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  revisionHistoryLimit: 3
  syncPolicy:
    syncOptions:
      - ApplyOutOfSyncOnly=true
      - CreateNamespace=true
      - FailOnSharedResource=true
      - PruneLast=true
    automated:
      prune: true
      selfHeal: true
EOF
}

unhelm(){
  log "REMOVE HELM SECRETS ..."

  # kubectl delete secret -A -l owner=helm
  kubectl get secret -A -l owner=helm
}

# RUN

cleanup
pause "cleanup"
init
pause "init"
install
pause "install"
push
pause "push"
bootstrap
pause "bootstrap"
unhelm
pause "unhelm"

# DONE

log "GITOPS READY !"
