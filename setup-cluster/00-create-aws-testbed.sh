#!/bin/bash
set -eio pipefail
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
cd $DIR

echo "You need AWS command line tools installed and authenticated for this to work"
echo "You need JQ to parse json outputs"
mkdir -p out

export AWS_CLI_OPTIONS="--output json"

set -x 

#
# Install SSH private key
#
SSH_KEY_NAME=MyKeyPair
if [[ ! -f out/key.pem ]] ; then 
    aws $AWS_CLI_OPTIONS ec2 create-key-pair --key-name $SSH_KEY_NAME > out/keypair.json
    if [[ $? != 0 ]] ; then 
        echo "Create VPC was unsuccessful"
        exit 1
    fi
    jq -r '.KeyMaterial' < out/keypair.js > out/key.pem
    chmod 400 out/key.pem
fi


#
# Create a VPC with an IP range similar to our corporate intranet
#
if [[ ! -f out/vpc.json ]] ; then 
    aws $AWS_CLI_OPTIONS ec2 create-vpc --cidr-block 10.0.0.0/16 > out/vpc.json
fi
VPC_ID=$(jq -r '.Vpc.VpcId'  < out/vpc.json)

#
# Check the VPC is done
#
vpc_state=$(aws $AWS_CLI_OPTIONS ec2 describe-vpcs --vpc-ids $VPC_ID | jq -r '.Vpcs[0].State')
if [[ $vpc_state != 'available' ]] ; then 
    echo "VPC is not ready. Please try again in a few minutes"
    exit 1
fi

#
# Create Subnet
#
if [[ ! -f out/subnet.json ]] ; then 
    aws $AWS_CLI_OPTIONS ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block 10.0.0.0/16 > out/subnet.json
    if [[ $? != 0 ]] ; then 
        echo "Subnet failed to create. Please try again in a few minutes"
        exit 1
    fi
fi
SUBNET_ID=$(jq -r '.Subnet.SubnetId'  < out/subnet.json)

#
# Create Internet Gateway and necessary route tables for the VPC
# So that machines on the network can have public IP addresses
# See https://docs.aws.amazon.com/vpc/latest/userguide/vpc-subnets-commands-example.html
#
if [[ ! -f out/igw.json ]] ; then 
    aws $AWS_CLI_OPTIONS ec2 create-internet-gateway > out/igw.json
    IGW_ID=$(jq -r '.InternetGateway.InternetGatewayId'  < out/igw.json)
    aws $AWS_CLI_OPTIONS  ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
fi

IGW_ID=$(jq -r '.InternetGateway.InternetGatewayId'  < out/igw.json)

if [[ ! -f out/routetable.json ]] ; then 
    aws $AWS_CLI_OPTIONS  ec2 create-route-table --vpc-id $VPC_ID > out/routetable.json
    
    ROUTETABLE_ID=$(jq -r '.RouteTable.RouteTableId'  < out/routetable.json)
    aws $AWS_CLI_OPTIONS  ec2 create-route --route-table-id $ROUTETABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

    aws $AWS_CLI_OPTIONS  ec2 associate-route-table  --subnet-id $SUBNET_ID --route-table-id $ROUTETABLE_ID
    aws $AWS_CLI_OPTIONS  ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch
fi
ROUTETABLE_ID=$(jq -r '.RouteTable.RouteTableId'  < out/routetable.json)


# 
# Aquire the default security group for the new VPC
#
if [[ ! -f out/sg.json ]] ; then 
    aws $AWS_CLI_OPTIONS ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID > out/sg.json
fi
GROUP_ID=$(jq -r '.SecurityGroups[0].GroupId' < out/sg.json)

#
# Add rule to allow my machine's public IP address to access
# any machine in the security group
#
MY_IP_ADDRESS=$(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com | sed s/\"//g)
if [[ ! -f out/authorize-sg.json ]] ; then 

    # slightly modify the calls if it is an IP6 or IP4 address
    if [[ "$MY_IP_ADDRESS" =~ ^[0-9a-f:]+$ ]] ; then 
        echo "IPv6 address '$MY_IP_ADDRESS' "
        aws $AWS_CLI_OPTIONS ec2 authorize-security-group-ingress \
            --group-id $GROUP_ID \
            --ip-permissions \
                "IpProtocol=tcp,FromPort=22,ToPort=22,Ipv6Ranges=[{CidrIpv6=$MY_IP_ADDRESS/128}]" \
                "IpProtocol=tcp,FromPort=6443,ToPort=6443,Ipv6Ranges=[{CidrIpv6=$MY_IP_ADDRESS/128}]" \
                "IpProtocol=tcp,FromPort=80,ToPort=80,Ipv6Ranges=[{CidrIpv6=::/0}]" \
                "IpProtocol=tcp,FromPort=443,ToPort=443,Ipv6Ranges=[{CidrIpv6=::/0}]" \
                "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}]" \
                "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0}]" > out/authorize-sg.json
    else
        echo "IPv4 address '$MY_IP_ADDRESS' "
        aws $AWS_CLI_OPTIONS ec2 authorize-security-group-ingress \
            --group-id $GROUP_ID \
            --ip-permissions \
                "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$MY_IP_ADDRESS/32}]" \
                "IpProtocol=tcp,FromPort=6443,ToPort=6443,IpRanges=[{CidrIp=$MY_IP_ADDRESS/32}]" \
                "IpProtocol=tcp,FromPort=80,ToPort=80,Ipv6Ranges=[{CidrIpv6=::/0}]" \
                "IpProtocol=tcp,FromPort=443,ToPort=443,Ipv6Ranges=[{CidrIpv6=::/0}]" \
                "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}]" \
                "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0}]" > out/authorize-sg.json
    fi
fi


#
# Create 4 EC2 instances for our cluster.
#
# debian-stretch-hvm-x86_64-gp2-2018-11-10-63975 - ami-017b679ef539c260f
IMAGE_ID=ami-017b679ef539c260f
INSTANCE_TYPE=t2.small
CLUSTER_SIZE_COUNT=4
if [[ ! -f out/instances.json ]] ; then 
    aws $AWS_CLI_OPTIONS ec2 run-instances \
        --image-id ${IMAGE_ID} \
        --key-name $SSH_KEY_NAME \
        --instance-type $INSTANCE_TYPE \
        --subnet-id $SUBNET_ID \
        --block-device-mappings "DeviceName=xvdb,VirtualName=xvdb,Ebs={DeleteOnTermination=true,VolumeSize=50,VolumeType=gp2,Encrypted=false}" \
        --network-interfaces DeviceIndex=0,AssociatePublicIpAddress=true,DeleteOnTermination=true \
        --count $CLUSTER_SIZE_COUNT > out/instances.json
    if [[ $? != 0 ]] ; then 
        echo "Create Instances was unsuccessful"
        exit 1
    fi
    jq -r '.Instances[].InstanceId' < out/instances.json > out/instance_ids.txt
fi

#
# Wait 30 seconds and download the public IPs for those new machines
#
if [[ ! -f out/instances_running.json ]] ; then 
    echo "Waiting 30 seconds to allow AWS to process"
    sleep 30
    aws --output json --profile yaas_stout_prod ec2 describe-instances --instance-ids $(cat out/instance_ids.txt) > out/instances_running.json
    jq -r '.Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp' < out/instances_running.json > out/public_ips.txt
fi

#
# Write common file to override cluster
#

master=( `jq -r '.Reservations[].Instances[0] | .NetworkInterfaces[].Association.PublicIp + "\t" +  .PrivateIpAddress +"\t"+.PrivateDnsName' < out/instances_running.json` )
ingress=( `jq -r '.Reservations[].Instances[1] | .NetworkInterfaces[].Association.PublicIp + "\t" +  .PrivateIpAddress +"\t"+.PrivateDnsName' < out/instances_running.json` )



node_hosts=( $(cat out/public_ips.txt) )
master_ip=${master[0]}
ingress_ip=${ingress[0]}
ingress_internal_ip=${ingress[1]}
ingress_host=$(sed s/.ec2.internal//g <<< "${ingress[2]}")

cat >out/common <<EOF
MASTER_NODE_HOSTNAME=${master_ip}
MASTER_NODE_IP=${master_ip}
INGRESS_EXTERNAL_IP=$ingress_ip
INGRESS_INTERNAL_IP=$ingress_internal_ip
INGRESS_NODE_NAME=$ingress_host
WORKER_NODES_HOSTNAMES=( \

EOF

for worker_ip in ${node_hosts[@]:1} ; do 
    echo "   $worker_ip \ " >> out/common
done
cat >>out/common <<EOF
    )
export SSH_OPTS="-i $DIR/out/key.pem"
EOF