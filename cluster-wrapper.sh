#!/usr/bin/env bash

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
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

get_subnet(){
  docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' $1
}

subnet_to_net(){
  echo $1 | sed "s@.0.0/16@@"
}

network

KIND_SUBNET_EXTERNAL=$(get_subnet kind)
KIND_SUBNET_SHORT=$(subnet_to_net $KIND_SUBNET_EXTERNAL)

while read bridge; do
  echo $bridge|grep -q ALLMULTI
  if [ "$?" -eq "0" ]; then
    LIMA_BRIDGE=$(echo $bridge | cut -d : -f 1)
    echo ${LIMA_BRIDGE}
  fi
done < <(ifconfig | grep -E 'bridge[0-9]*:') 

LIMA_IP_ADDR_EXTERNAL=$(ifconfig ${LIMA_BRIDGE}|grep "inet " | awk '{print $2}')

echo $KIND_SUBNET_EXTERNAL $KIND_SUBNET_SHORT $LIMA_IP_ADDR_EXTERNAL

export KIND_SUBNET_EXTERNAL KIND_SUBNET_SHORT LIMA_IP_ADDR_EXTERNAL

envsubst '$KIND_SUBNET_SHORT, $KIND_SUBNET_EXTERNAL, $LIMA_IP_ADDR_EXTERNAL' < cluster-template.sh > ./cluster.sh
