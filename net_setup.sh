#!/bin/bash
source ~/openrc
# Our generic lab model is to create a network that uses the VLAN id to help
# define Subnet IPs.  We'll do this here for both our "public" access network
# and for the OpenStack L3 agent NATd network

function die ( ) {
  echo $@
  exit 1
}

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Find the Public and private networks:
[ -e .network ] && source .network 
[ -z ${PUB_IP} ] && PUB_IP="192.168.0.0"
read -t 5 -p "What is your public network IP [${PUB_IP}]: " IP_IN
[ -z ${IP_IN} ] ||PUB_IP=${IP_IN}
if  ! valid_ip ${PUB_IP} ; then
 die "Please enter a valid public ip"
fi

[ -z ${PUB_CIDR} ] && PUB_CIDR='24'
read -t 5 -p "What is the CIDR for that network[${PUB_CIDR}]: " PUB_CIDR
[ -z ${PUB_CIDR} ] && PUB_CIDR='24'
# We use 192.168.VLAN.0/24 as our public network range(s)
PUB_NET="${PUB_IP}/${PUB_CIDR}"

echo "export PUB_IP=${PUB_IP}" > .network
echo "export PUB_CIDR=${PUB_CIDR}" >> .network

# We use 10.VLAN.1.0/24 for our private default network(s)
# Find the Private and private networks:
[ -z ${PRIV_IP} ] && PRIV_IP="10.168.0.0"
read -t 5 -p "What is your private network IP [${PRIV_IP}]: " IP_IN
[ -z ${IP_IN} ] || PRIV_IP=${IP_IN}
if  ! valid_ip ${PRIV_IP} ; then
 die "Please enter a valid public ip"
fi
[ -z ${PRIV_CIDR} ] && PRIV_CIDR='24'
read -t 5 -p "What is the CIDR for that network[${PRIV_CIDR}]: " PRIV_CIDR
[ -z ${PRIV_CIDR} ] && PRIV_CIDR='24'
PRIV_NET="${PRIV_IP}/${PRIV_CIDR}"

echo "export PRIV_IP=${PRIV_IP}" >> .network
echo "export PRIV_CIDR=${PRIV_CIDR}" >> .network

#
echo "Public Private Subnets: ${PUB_NET} ${PRIV_NET}"

# Create a the public network, the l3 agent connection, and associate an IP
# subnet to it
PUB_NET_ID=`quantum net-list | grep public`
[ -z "${PUB_NET_ID}" ] || die 'Delete your networks and try again'
if ! PUB_NET_ID=`quantum net-create public --router:external=True | grep ' id ' | awk -F' ' '{print $4}'`; then
 echo 'no public net created'
 exit 1
fi

if ! PUB_SUBNET_ID=`quantum subnet-create public ${PUB_NET} | grep ' id ' | awk -F' ' '{print $4}'` ; then
 echo 'no public subnet created'
 exit 1
fi
echo "Public Net and Subnet ID: ${PUB_NET_ID} ${PUB_SUBNET_ID}"
# Create the private network, ans assicate an IP, L3 cnnection is next
PRIV_NET_ID=`quantum net-create private | grep ' id ' | awk -F' ' '{print $4}'`
PRIV_SUBNET_ID=`quantum subnet-create private ${PRIV_NET} | grep ' id ' | awk -F' ' '{print $4}'`
echo "Private Net and Subnet ID: ${PRIV_NET_ID} ${PRIV_SUBNET_ID}"
# Create a router, and connect it to the private network
PRIV_ROUTER=`quantum router-create private_router_1 | grep ' id ' | awk -F' ' '{print $4}'`
# now attach the router to the private network port
PRIV_ROUTER_INT=`quantum router-interface-add private_router_1 "${PRIV_SUBNET_ID}"| grep ' id ' | awk -F' ' '{print $4}'`
# Now connect the router to the external public newtork
PUB_PRIV_ROUTER=`quantum router-gateway-set private_router_1 "${PUB_NET_ID}" | grep ' id ' | awk -F' ' '{print $4}'`
PUB_NETWORK=`quantum port-list -- --device_id ${PRIV_ROUTER} --device_owner network:router_gateway | grep ip_address | awk -F'"' '{print $8}'`
#PRIV_ROUTER=`quantum router-list | grep private_router_1 | awk -F' ' '{print $2}'`
echo "Private Router and Subnet ID: qrouter-${PRIV_ROUTER} ${PUB_NETWORK}"
