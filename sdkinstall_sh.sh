#!/bin/bash
#  after vagrant up, vagrant ssh into the guest and
#  run the script /vagrant/sdkinstall.sh FQDN
# FQDN is the full qualified domain name you want to 
# assign to the host
# e.g.
#      /vagrant/sdkinstall.sh obcs.oracledemo.com
#
# check arguments
myhost=$1
if [ -z "$myhost" ]; then
   echo "Please provide FQDN, e.g."
   echo "    /vagrant/sdkinstall obcs.oracledemo.com"
   exit 1
fi
# disable selinx
echo "auto prepare and install everything, and setting up the guest vm as host $myhost"
echo
echo "=== Disabling SELinux"
sudo setenforce 0
sudo sed -i --follow-symlinks 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux
# stop & disable firewalld
echo "=== Stopping and disabling firewalld"
sudo systemctl disable firewalld
sudo systemctl stop firewalld
# install docker and other required package
echo "=== adding yum packages"
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install git docker-ce zip unzip -y
# enable and start docker
echo "=== starting docker"
sudo systemctl enable docker
sudo systemctl start docker
# create a docker network for obp
echo "=== creating docker network for OBP SDK"
sudo docker network create obcs_default
# setting up oracle user
echo "=== setting up oracle user & adding to groups"
sudo useradd oracle
sudo usermod -aG docker oracle
sudo usermod -aG vagrant oracle
sudo usermod -aG vboxsf oracle
# install docker compose
echo "=== installing docker-compose"
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
# install docker auto completion
echo "=== installing command-line completion"
sudo curl -L https://raw.githubusercontent.com/docker/compose/1.24.0/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose
# copy SDK from host
echo "=== copying SDK zip file from host machine"
sudo cp /vagrant/obcs-sdk-19.2.1-20190329015212.zip /home/oracle
sudo chown oracle:oracle /home/oracle/obcs-sdk-19.2.1-20190329015212.zip
# unzip SDK to /home/oracle/sdk
echo "=== unzipping sdk"
sudo -H -u oracle unzip -d /home/oracle/sdk /home/oracle/obcs-sdk-19.2.1-20190329015212.zip
sudo -H -u oracle mkdir /home/oracle/obcs_workspace
# build SDK
echo "=== building sdk by loading docker images"
sudo -H -u oracle /home/oracle/sdk/build.sh -d /home/oracle/sdk
# SDK ready.... do our tricks
echo "solving the FQDN problem"
# get my IP
myip=$(ifconfig eth0 | grep inet\ | awk '{print $2}')
# create the entry in hosts file
echo "$myip    $myhost" | sudo tee -a /etc/hosts
# get the ID of provisioning container
provcont=$(sudo docker ps -q)
# create the dummy container with the dns name
sudo docker run -d -t --network=obcs_default --name=$myhost bcs/crc bash
# restart my provisioning docker
sudo docker restart $provcont
