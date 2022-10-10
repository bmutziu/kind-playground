#!/usr/bin/env bash

set -e

# CONSTANTS

readonly KIND_NODE_IMAGE=kindest/node:v1.25.2@sha256:9be91e9e9cdf116809841fc77ebdb8845443c4c72fe5218f3ae9eb57fdb4bace
readonly DNSMASQ_DOMAIN=kind.cluster
readonly DNSMASQ_CONF=kind.k8s.conf

shopt -s expand_aliases
alias klssha='kitty +kitten ssh -o 'IdentityFile="/Users/bmutziu/.lima/_config/user"' -o 'IdentityFile="/Users/bmutziu/.ssh/google_compute_engine"' -o 'IdentityFile="/Users/bmutziu/.ssh/id_rsa"' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o NoHostAuthenticationForLocalhost=yes -o GSSAPIAuthentication=no -o PreferredAuthentications=publickey -o Compression=no -o BatchMode=yes -o IdentitiesOnly=yes -o 'Ciphers="^aes128-gcm@openssh.com,aes256-gcm@openssh.com"' -o User=bmutziu -o ControlMaster=auto -o 'ControlPath="/Users/bmutziu/.lima/docker-0/ssh.sock"' -o ControlPersist=5m -o ForwardAgent=yes -o Hostname=127.0.0.1 -o Port=60606 lima-docker-0'

# FUNCTIONS

# init
function pause(){
   read -p "$*"
}

function klssh(){
  local CMD=$1
  kitty +kitten ssh -o 'IdentityFile="/Users/bmutziu/.lima/_config/user"' -o 'IdentityFile="/Users/bmutziu/.ssh/google_compute_engine"' -o 'IdentityFile="/Users/bmutziu/.ssh/id_rsa"' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o NoHostAuthenticationForLocalhost=yes -o GSSAPIAuthentication=no -o PreferredAuthentications=publickey -o Compression=no -o BatchMode=yes -o IdentitiesOnly=yes -o 'Ciphers="^aes128-gcm@openssh.com,aes256-gcm@openssh.com"' -o User=bmutziu -o ControlMaster=auto -o 'ControlPath="/Users/bmutziu/.lima/docker-0/ssh.sock"' -o ControlPersist=5m -o ForwardAgent=yes -o Hostname=127.0.0.1 -o Port=60606 lima-docker-0 "${CMD}"
}

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

wait_ready(){
  local NAME=${1:-pods}
  local TIMEOUT=${2:-5m}
  local SELECTOR=${3:---all}

  log "WAIT $NAME ($TIMEOUT) ..."

  kubectl wait -A --timeout=$TIMEOUT --for=condition=ready $NAME $SELECTOR
}

wait_pods_ready(){
  local TIMEOUT=${1:-5m}

  wait_ready pods $TIMEOUT --field-selector=status.phase!=Succeeded
}

wait_nodes_ready(){
  local TIMEOUT=${1:-5m}

  wait_ready nodes $TIMEOUT
}

network(){
  local NAME=${1:-kind}

  log "NETWORK (kind) ..."

  if [ -z $(docker network ls --filter name=^$NAME$ --format="{{ .Name }}") ]
  then 
    docker network create $NAME
    echo "Network $NAME created"
  else
    echo "Network $NAME already exists, skipping"
  fi
}

proxy(){
  local NAME=$1
  local TARGET=$2

  if [ -z $(docker ps --filter name=^${NAME}$ --format="{{ .Names }}") ]
  then
    docker run -d --name $NAME --restart=always --net=kind -e REGISTRY_PROXY_REMOTEURL=$TARGET registry:2
    echo "Proxy $NAME (-> $TARGET) created"
  else
    echo "Proxy $NAME already exists, skipping"
  fi
}

proxies(){
  log "REGISTRY PROXIES ..."

  proxy proxy-docker-hub https://registry-1.docker.io
  proxy proxy-quay       https://quay.io
  proxy proxy-gcr        https://gcr.io
  proxy proxy-k8s-gcr    https://k8s.gcr.io
}

get_service_lb_ip(){
  kubectl get svc -n $1 $2 -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
}

get_subnet(){
  docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' $1
}

subnet_to_ip(){
  echo $1 | sed "s@0.0/16@$2@"
}

root_ca(){
  log "ROOT CERTIFICATE ..."

#  mkdir -p .ssl
#
#  if [[ -f ".ssl/root-ca.pem" && -f ".ssl/root-ca-key.pem" ]]
#  then
#    echo "Root certificate already exists, skipping"
#  else
#    openssl genrsa -out .ssl/root-ca-key.pem 2048
#    openssl req -x509 -new -nodes -key .ssl/root-ca-key.pem -days 3650 -sha256 -out .ssl/root-ca.pem -subj "/CN=kube-ca"
#    echo "Root certificate created"
#  fi

klssha '
mkdir -p .ssl

if [[ -f ".ssl/root-ca.pem" && -f ".ssl/root-ca-key.pem" ]]
then
  echo "Root certificate already exists, skipping"
else
  openssl genrsa -out .ssl/root-ca-key.pem 2048
  openssl req -x509 -new -nodes -key .ssl/root-ca-key.pem -days 3650 -sha256 -out .ssl/root-ca.pem -subj "/CN=kube-ca"
  echo "Root certificate created"
fi
'

string_root_ca=$(cat << EOF
mkdir -p .ssl

if [[ -f ".ssl/root-ca.pem" && -f ".ssl/root-ca-key.pem" ]]
then
  echo "Root certificate already exists, skipping"
else
  openssl genrsa -out .ssl/root-ca-key.pem 2048
  openssl req -x509 -new -nodes -key .ssl/root-ca-key.pem -days 3650 -sha256 -out .ssl/root-ca.pem -subj "/CN=kube-ca"
  echo "Root certificate created"
fi
EOF
)

klssh "$string_root_ca"
}

install_ca(){
  log "INSTALL CERTIFICATE AUTHORITY ..."

  #sudo mkdir -p /usr/local/share/ca-certificates/kind.cluster

  #sudo cp -f .ssl/root-ca.pem /usr/local/share/ca-certificates/kind.cluster/ca.crt

  #sudo update-ca-certificates

  klssha '
  sudo mkdir -p /usr/local/share/ca-certificates/kind.cluster
  sudo cp -f .ssl/root-ca.pem /usr/local/share/ca-certificates/kind.cluster/ca.crt
  sudo update-ca-certificates
  '

  string_install_ca=$(cat << EOF
  sudo mkdir -p /usr/local/share/ca-certificates/kind.cluster
  sudo cp -f .ssl/root-ca.pem /usr/local/share/ca-certificates/kind.cluster/ca.crt
  sudo update-ca-certificates
EOF
  )

  klssh "$string_install_ca"
}

cluster(){
  local NAME=${1:-kind}

  log "CLUSTER ..."

  sshfs bmutziu@lima-docker-0:/home/bmutziu.linux ~/guest -ocache=no -onolocalcaches -ovolname=ssh
  ln -sf ~/guest/.ssl .

  docker pull $KIND_NODE_IMAGE

  kind create cluster --name $NAME --image $KIND_NODE_IMAGE --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  kubeProxyMode: none
kubeadmConfigPatches:
  - |-
    kind: ClusterConfiguration
    apiServer:
      extraVolumes:
        - name: opt-ca-certificates
          hostPath: /opt/ca-certificates/root-ca.pem
          mountPath: /opt/ca-certificates/root-ca.pem
          readOnly: true
          pathType: File
      extraArgs:
        oidc-client-id: kube
        oidc-issuer-url: https://keycloak.kind.cluster/auth/realms/master
        oidc-username-claim: email
        oidc-groups-claim: groups
        oidc-ca-file: /opt/ca-certificates/root-ca.pem
    controllerManager:
      extraArgs:
        bind-address: 0.0.0.0
    etcd:
      local:
        extraArgs:
          listen-metrics-urls: http://0.0.0.0:2381
    scheduler:
      extraArgs:
        bind-address: 0.0.0.0
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["http://proxy-docker-hub:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
      endpoint = ["http://proxy-quay:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
      endpoint = ["http://proxy-k8s-gcr:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
      endpoint = ["http://proxy-gcr:5000"]
nodes:
  - role: control-plane
    extraMounts:
      - hostPath: $PWD/.ssl/root-ca.pem
        containerPath: /opt/ca-certificates/root-ca.pem
        readOnly: true
  - role: control-plane
    extraMounts:
      - hostPath: $PWD/.ssl/root-ca.pem
        containerPath: /opt/ca-certificates/root-ca.pem
        readOnly: true
  - role: control-plane
    extraMounts:
      - hostPath: $PWD/.ssl/root-ca.pem
        containerPath: /opt/ca-certificates/root-ca.pem
        readOnly: true
  - role: worker
    extraMounts:
      - hostPath: $PWD/.ssl/root-ca.pem
        containerPath: /opt/ca-certificates/root-ca.pem
        readOnly: true
  - role: worker
    extraMounts:
      - hostPath: $PWD/.ssl/root-ca.pem
        containerPath: /opt/ca-certificates/root-ca.pem
        readOnly: true
  - role: worker
    extraMounts:
      - hostPath: $PWD/.ssl/root-ca.pem
        containerPath: /opt/ca-certificates/root-ca.pem
        readOnly: true
EOF
}

cilium(){
  log "CILIUM ..."

  helm upgrade --install --wait --timeout 27m --atomic --namespace kube-system --create-namespace \
    --repo https://helm.cilium.io cilium cilium --values - <<EOF
kubeProxyReplacement: strict
k8sServiceHost: kind-external-load-balancer
k8sServicePort: 6443
socketLB:
  enabled: true
externalIPs:
  enabled: true
nodePort:
  enabled: true
hostPort:
  enabled: true
image:
  pullPolicy: IfNotPresent
ipam:
  mode: kubernetes
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
    ingress:
      enabled: true
      annotations:
        kubernetes.io/ingress.class: nginx
        cert-manager.io/cluster-issuer: ca-issuer
      hosts:
        - hubble-ui.$DNSMASQ_DOMAIN
      tls:
        - secretName: hubble-ui.$DNSMASQ_DOMAIN
          hosts:
            - hubble-ui.$DNSMASQ_DOMAIN
EOF
}

cert_manager(){
  log "CERT MANAGER ..."

  helm upgrade --install --wait --timeout 15m --atomic --namespace cert-manager --create-namespace \
    --repo https://charts.jetstack.io cert-manager cert-manager --values - <<EOF
installCRDs: true
EOF
}

cert_manager_ca_secret(){
  kubectl delete secret -n cert-manager root-ca || true
  kubectl create secret tls -n cert-manager root-ca --cert=.ssl/root-ca.pem --key=.ssl/root-ca-key.pem
}

cert_manager_ca_issuer(){
  kubectl apply -n cert-manager -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: root-ca
EOF
}

metallb(){
  log "METALLB ..."

  local KIND_SUBNET=$(get_subnet kind)
  local METALLB_START=$(subnet_to_ip $KIND_SUBNET 255.200)
  local METALLB_END=$(subnet_to_ip $KIND_SUBNET 255.250)

  #helm upgrade --install --wait --timeout 15m --atomic --namespace metallb-system --create-namespace \
  #  --repo https://metallb.github.io/metallb metallb metallb --version 0.12.1 --values - <<EOF
#configInline:
#  address-pools:
#    - name: default
#      protocol: layer2
#      addresses:
#        - $METALLB_START-$METALLB_END
#EOF
  helm upgrade --install --wait --timeout 15m --atomic --namespace metallb-system --create-namespace --repo https://metallb.github.io/metallb metallb metallb

  cat << EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-ip
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - $METALLB_START-$METALLB_END
EOF
}

ingress(){
  log "INGRESS-NGINX ..."

  helm upgrade --install --wait --timeout 15m --atomic --namespace ingress-nginx --create-namespace \
    --set defaultBackend.image.repository="k8s.gcr.io/defaultbackend-arm64" \
    --repo https://kubernetes.github.io/ingress-nginx ingress-nginx ingress-nginx --values - <<EOF
defaultBackend:
  enabled: true
EOF
}

dnsmasq(){
  log "DNSMASQ ..."

  klssh "sudo apt install -y dnsmasq"

  klssh "sudo systemctl stop systemd-resolved && sudo systemctl disable systemd-resolved && sudo systemctl mask systemd-resolved"

  string_dnsmasq=$(cat << EOF
  cat << FOE > /tmp/dnsmasq.conf
  bind-interfaces
  listen-address=127.0.0.1
  server=8.8.8.8
  server=8.8.4.4
  conf-dir=/etc/dnsmasq.d/,*.conf
FOE
EOF
)

  string_hosts=$(cat << EOF
  LIMA_IF=\$(ip -o -4 a s | grep lima0 | grep -E -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2)
  echo -e '\n'\${LIMA_IF} lima-docker-0 | sudo tee -a /etc/hosts
EOF
  )

  klssh "$string_hosts"

  local INGRESS_LB_IP=$(get_service_lb_ip ingress-nginx ingress-nginx-controller)

  klssh "echo 'address=/$DNSMASQ_DOMAIN/$INGRESS_LB_IP' | sudo tee /etc/dnsmasq.d/$DNSMASQ_CONF"
}

restart_service(){
  log "RESTART $1 ..."

  klssh "sudo systemctl restart $1"
}

routing(){
  log "routing"

  local LIMA_IP_ADDR=$(ssh bmutziu@lima-docker-0 -- ip -o -4 a s | grep lima0 | grep -E -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2)
  echo $LIMA_IP_ADDR

  sudo route -nv add -net 172.18 ${LIMA_IP_ADDR}

  #klssha '
  #KIND_IF=$(ip -o link show|cut -d " " -f 2|grep "br-")
  #SRC_IP=192.168.105.1
  #DST_NET=172.19.0.0/16
  #HOST_IF=lima0
  #sudo iptables -t filter -A FORWARD -4 -p tcp -s ${SRC_IP} -d ${DST_NET} -j ACCEPT -i ${HOST_IF} -o ${KIND_IF%?}
  #sudo iptables -L
  #'

  string_routing=$(cat << EOF
  KIND_IF=\$(ip -o link show|cut -d " " -f 2|grep "br-")
  SRC_IP=192.168.105.1
  DST_NET=172.18.0.0/16
  HOST_IF=lima0
  sudo iptables -t filter -A FORWARD -4 -p tcp -s \${SRC_IP} -d \${DST_NET} -j ACCEPT -i \${HOST_IF} -o \${KIND_IF%?}
  sudo iptables -L -n -v|grep \${HOST_IF}
EOF
  )

  klssh "$string_routing"
}
cleanup(){
  log "CLEANUP ..."

  umount /Users/bmutziu/guest
  kind delete cluster || true
  klssh "sudo rm -f /etc/dnsmasq.d/$DNSMASQ_CONF"
  klssh "sudo rm -rf /usr/local/share/ca-certificates/kind.cluster"

  local LIMA_IP_ADDR=$(ssh bmutziu@lima-docker-0 -- ip -o -4 a s | grep lima0 | grep -E -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2) 
  sudo route -nv delete -net 172.18 ${LIMA_IP_ADDR}

string_cleanup_routing=$(cat << EOF
  KIND_IF=\$(ip -o link show|cut -d " " -f 2|grep "br-")
  SRC_IP=192.168.105.1
  DST_NET=172.18.0.0/16
  HOST_IF=lima0
  sudo iptables -t filter -D FORWARD -4 -p tcp -s \${SRC_IP} -d \${DST_NET} -j ACCEPT -i \${HOST_IF} -o \${KIND_IF%?}
  sudo iptables -L -n -v|grep \${HOST_IF}
EOF
  )

  klssh "$string_cleanup_routing"
}

# RUN

# cleanup
pause "cleanup"
# network
# proxies
pause "network proxies"
# root_ca
# install_ca
pause "[root|install]_ca"
# cluster
pause "cluster"
# cilium
pause "cilium"
cert_manager
cert_manager_ca_secret
cert_manager_ca_issuer
pause "cert_manager"
metallb
pause "metallb"
ingress
pause "ingress"
# dnsmasq
# restart_service dnsmasq
# pause "dnsmasq"
routing
pause "routing"

# DONE

log "CLUSTER READY !"

# 127.0.0.1 hubble-ui.kind.cluster (/etc/hosts)
# ssh -L 9996:172.19.255.200:443 -o Hostname=127.0.0.1 -o Port=60606 lima-docker-0
echo "HUBBLE UI: https://hubble-ui.$DNSMASQ_DOMAIN"
