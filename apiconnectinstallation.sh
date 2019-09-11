#!/bin/sh
ip=`curl ifconfig.me`
NAMESPACE=apiconnect
sudo sysctl -w vm.max_map_count=262144
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
echo "+++++++++++++++formate extra hdd++++++++++++++++++++++++++++++++++++"
mkfs.ext4 /dev/xvdc
echo "+++++++++++++++create folder++++++++++++++++++++++++++++++++++++++++"
mkdir /var/lib/docker
echo "+++++++++++++++++++mount extra hdd to docker folder++++++++++++++++++++++++++++++++++"
mount /dev/xvdc /var/lib/docker
echo "++++++++++++++++++++add line in fdisk file+++++++++++++++++++++++++++++++++++++++++++"
echo "/dev/xvdc /var/lib/docker ext4 defauls 0 0 " >> /etc/fstab
echo  "install openshift on ubuntu server"
sudo apt-get update && sudo apt-get install -y apt-transport-https
sudo apt-get  install -y docker.io
 sudo systemctl start docker
sudo systemctl enable docker

wget https://get.helm.sh/helm-v2.14.3-linux-amd64.tar.gz
tar -zxvf helm-*.tar.gz
cp linux-amd64/helm /usr/local/bin/helm
cp linux-amd64/helm /usr/bin/helm
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt-get update
sudo apt-get -y install python2.7
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add

echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl docker-compose kubernetes-cnis
echo "openshift"
wget https://github.com/openshift/origin/releases/download/v3.9.0/openshift-origin-client-tools-v3.9.0-191fece-linux-64bit.tar.gz 
tar -zvxf openshift-origin-client-tools-v3.9.0-191fece-linux-64bit.tar.gz
cd openshift-origin-client-tools-v3.9.0-191fece-linux-64bit
sudo cp oc /usr/local/bin/
oc version
echo "add line in daemon.json file"

cat << EOF > /etc/docker/daemon.json 
{
    "insecure-registries" : [ "172.30.0.0/16" ]
}
EOF

echo "restart docker service"
service docker restart
echo "cluster up "



oc cluster up  --public-hostname="$ip" --host-data-dir=/var/lib/docker/mydata --use-existing-config

oc login https://$ip:8443  -u developer -p developer -n apiconnect --insecure-skip-tls-verify


oc adm policy add-scc-to-group anyuid system:authenticated

oc adm policy add-cluster-role-to-user cluster-admin developer --config=/var/lib/origin/openshift.local.config/master/admin.kubeconfig

oc create clusterrolebinding serviceaccounts-cluster-admin \
  --clusterrole=cluster-admin \
  --group=system:serviceaccounts


oc new-project apiconnect

echo "apicup  "
scp -r root@52.117.37.99:/root/apiconnect /root/
cp /root/apiconnect/apicup-linux_lts_v2018.4.1.6-ifix3.0 /usr/bin/apicup
sudo chmod 755 /usr/bin/apicup

echo "copy data from server "

oc login https://$ip:8443  -u developer -p developer -n apiconnect --insecure-skip-tls-verify



cd /root
git clone https://github.com/milindlasurve/infile.git
cd infile
oc create -f  ClusterRoleBindings.yaml
oc create -f hostpath-prov-SCC.yaml
oc patch scc hostpath -p '{"allowHostDirVolumePlugin": true}'
oc adm policy add-scc-to-group hostpath system:authenticated
oc create -f hostpath-prov-ClusterRole.yaml
oc create -f hostpath-prov-ClusterRoleBinding.yaml

oc create -f hostpath-prov-Deployment.yaml
oc rollout status deployment hostpath-provisioner
oc create -f hostpath-prov-StorageClass.yaml
oc new-project tiller
export TILLER_NAMESPACE=tiller
echo "export TILLER_NAMESPACE=tiller" >> /root/.bashrc
helm init --client-only
oc process -f https://github.com/openshift/origin/raw/master/examples/helm/tiller-template.yaml -p TILLER_NAMESPACE="${TILLER_NAMESPACE}" -p HELM_VERSION=v2.14.3 | oc create -f -
oc rollout status deployment tiller
helm version
helm list
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:tiller:tiller
oc project apiconnect
oc adm policy add-scc-to-group anyuid system:serviceaccounts:apiconnect
cd /root
git clone https://github.com/JoelGauci/apicv2018.git
cd /root/apicv2018/save
sudo apt-get install -y docker-compose
mkdir -p /opt/registry/auth
mkdir /opt/registry/data
sudo docker run --entrypoint htpasswd registry:2 -Bbn admin admin >> /opt/registry/auth/htpasswd
cd /root/apicv2018/save
 sudo docker-compose up -d && sudo docker ps
docker login -u admin -p admin localhost:5000
oc create secret docker-registry apic-secret --docker-server=localhost:5000 --docker-username=admin --docker-password=admin --docker-email=milind@cateina.com -n apiconnect


oc create -f storage-rbac.yaml -n apiconnect
oc  create -f hostpath-provisioner.yaml -n apiconnect
oc create -f StorageClass.yaml -n apiconnect
cd /root/apiconnect

apicup registry-upload management management-images-kubernetes_lts_v2018.4.1.6-ifix3.0.tgz localhost:5000 --accept-license --debug
apicup registry-upload analytics analytics-images-kubernetes_lts_v2018.4.1.6-ifix3.0.tgz localhost:5000 --accept-license --debug
apicup registry-upload portal portal-images-kubernetes_lts_v2018.4.1.6-ifix3.0.tgz localhost:5000 --accept-license --debug

mkdir myProject
cd myProject
apicup init
	
docker pull ibmcom/datapower:2018.4.1.6.309660
docker pull busybox:1.29-glibc
docker tag busybox:1.29-glibc localhost:5000/datapower/busybox:1.29-glibc
docker tag ibmcom/datapower:2018.4.1.6.309660 localhost:5000/datapower/datapower-api-gateway:2018.4.1.6-309660-release-prod
docker push localhost:5000/datapower/busybox:1.29-glibc
docker push localhost:5000/datapower/datapower-api-gateway:2018.4.1.6-309660-release-prod


cp /root/infile/apiconnect-up.yml /root/apiconnect/myProject/
echo "sed -i 's/169.62.184.118/"$ip"/g' apiconnect-up.yml " > /tmp/shell.sh
sh /tmp/shell.sh

cd /root/apiconnect/myProject/
apicup subsys install mgmt --debug
apicup subsys install portal --debug
apicup subsys install a7s --debug
apicup subsys install gwy --debug
