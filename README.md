# Installing IBM API Connect v2018 on OpenShift Origin v3.9 or v3.10

## Setup a single node OpenShift environment (optional)

### CentOS installation

Download the minimal CentOS image from [https://www.centos.org/download/](https://www.centos.org/download/) . The configuration described in this document was based on the **_CentOS-7-x86_64-Minimal-1804.iso_** image.
Install this image on a physical or virtual machine.

### Update packages, install Docker

Update all packages and restart CentOS:
```sh
yum update
shutdown -r now 
```

Once the operating system has restarted, install git, Docker and net tools:
```sh
yum install -y git docker net-tools
```

Start Docker:
```sh
systemctl restart docker
systemctl enable docker
```

Verify that Docker works:
```sh
docker run hello-world
```

### Install OpenShift Origin

The installation used here is based on: [https://github.com/gshipley/installcentos](https://github.com/gshipley/installcentos). I recommend that you also view  the following video: [https://www.youtube.com/watch?v=aqXSbDZggK4](https://www.youtube.com/watch?v=aqXSbDZggK4).


>**NOTE:**
>I recommend to run all the commands with **root** privileges (or use **sudo**).

Clone the installation scripts:
```sh
git clone https://github.com/gshipley/installcentos.git
```

The next few steps prepare environment variables that will be used by the installation script.

If you don't have a DNS, you can use a wildcard domain, built from the server IP address and extension **nip.io**. For exmaple, the IP address of my server was *10.101.192.18*, so I defined the domain as **10.101.192.18.nip.io**.

Run the following command, altered to include the IP address of your server:
```sh
export DOMAIN=10.101.192.18.nip.io
```

Define a user name and password. This user will become an administrator of the OpenShift cluster. In the following command I chose *ibm* as a username, with password *Passw0rd*. You can change both to whatever you want.
```sh
export USERNAME=ibm
export PASSWORD=Passw0rd
```

Navigate to the previously-cloned folder and run the installation script. 
```sh
cd installcentos
./install-openshift.sh
```

When the script completes, you will have installed a single node OpenShift Origin cluster, plus CLI tools (**oc** and **kubectl**).

## Install IBM API Connect

>**NOTE:**
>I recommend that you run all the commands shown using **root** privileges (or use **sudo**).

### Prepare operating system

Increase **vm.max_map_count**
```sh
sysctl -w vm.max_map_count=262144
```

To permanently store this, edit **/etc/sysctl.conf** and add this line
```sh
vm.max_map_count=262144
```

### Download images

The required images can be downloaded from [IBM Fix Central](https://www-945.ibm.com/support/fixcentral/).
Search for IBM API Connect and select the version that you want.

Download the following images:
* **management-images-kubernetes_v2018.x.y.tgz**
* **analytics-images-kubernetes_v2018.x.y.tgz**
* **portal-images-kubernetes_v2018.x.y.tgz**

and the following command line tool:
* **apicup-linux_v2018.x.y**

where **x.y** means version. (In this document, I am using version 2018.3.5 throughout, but be aware that other versions are available. )

Copy the above files (for example using ```scp```) to a unique directory on your OpenShift machine.

### Install CLI tool

Move **apicup** ato **/usr/bin** and make it executable:
```sh
cp apicup-linux_v2018.x.y /usr/bin
mv /usr/bin/apicup-linux_v2018.x.y /usr/bin/apicup
chmod 755 /usr/bin/apicup
``` 

Verify with:
```sh
apicup --help
``` 

The command replies with:
```console
Please review the license for API Connect by running "apic licenses" command
or accessing https://ibm.biz/apictoolkitlic.
Accept the license for API Connect [Y/N] 	
```

Type **Y** to accept

### Login to OpenShift and create project

Run the following command to log in (enter the username and password when asked) :
```sh
oc login
```

*Note: this is an alternative way to login:*
* *Log in to the OpenShift web console (https://console.<your_domain>:8443/console)*
* *Click on the user icon on top right* 
* *Select "Copy Login Command"*
* *Paste to the command line*

Create a new project named **apiconnect**.
```sh
oc new-project apiconnect
```

Note: The concept of a project in OpenShift is equivalent to the concept of a namespace in other Kubernetes implementations. When you run standard *kubectl* commands, you can use the project name wherever Kubernetes needs the namespace parameter. 

One project is always specified as the current project, which you will see after logging in. When you create a new project, the new one automatically becomes the current project. If, for any reason, you navigate to another project, you can return to your *apiconnect* project with the command:
```sh
os project apiconnect
```

You can list all projects with the command:
```sh
os projects
```

### Login to the OpenShift's Docker registry

You need to determine the registry ClusterIP address. The easiest way to do this is to run:
```sh
oc get svc -n default | grep registry
```

Note the address and port of the service called **docker-registry**.

Use that information to login to the registry:
```sh
docker login -u `oc whoami` -p `oc whoami -t` <registry-address>:<port>
```

... where *\<registry_address\>* and *\<port\>* are the address and port obtained from the previous command.
For entering the username and password, the *oc whami* command is used above. Note: this is contained within **back-quotes** and not ordinary quotes.

On my test installation the above looked like this:
```console
$ oc get svc -n default | grep registry
docker-registry    ClusterIP   172.30.148.162   <none>        5000/TCP                  3h
registry-console   ClusterIP   172.30.5.53      <none>        9000/TCP                  3h
$ docker login -u `oc whoami` -p `oc whoami -t` 172.30.167.132:5000
Login Succeeded
```

>**NOTE:**
>
>Depending on the version of Docker and your cluster configuration, you may get the following error:
>```console
>Error response from daemon: Get https://172.30.148.162:5000/v1/users/: x509: certificate signed by unknown authority
>```
>
>The solutions are to use a properly signed certificate (beyond the scope fo thid document, please refer OpenShift and Docker documentation), or to list this registry as a trusted insecure registry under the Docker configuration.
>
>Open **/etc/docker/daemon.json** file in editor, for example:
>```sh
>vi /etc/docker/daemon.json
>```
>
>and add the following line altered to include the IP address of your registry:
>```console
>{"insecure-registries":["172.30.148.162:5000"]}
>```
>
>Save the file and restart Docker:
>```sh
>systemctl restart docker
>```

### Upload images to registry

Run the following to upload the images to your registry:
```sh
apicup registry-upload management management-images-kubernetes_v2018.x.y.tgz <registry-address>:<port> --accept-license --debug

apicup registry-upload analytics analytics-images-kubernetes_v2018.x.y.tgz <registry-address>:<port> --accept-license --debug

apicup registry-upload portal portal-images-kubernetes_v2018.x.y.tgz <registry-address>:<port> --accept-license --debug
```

...where **x.y** is the version of the previously downloaded API Connect packages and **< registry-address >:< port >** are previously determined registry service IP address and port (default 5000).

On my server, the above looked like this:
```console
$ apicup registry-upload management management-images-kubernetes_v2018.3.5.tgz 172.30.148.162:5000 --accept-license --debug
$ apicup registry-upload analytics analytics-images-kubernetes_v2018.3.5.tgz 172.30.148.162:5000 --accept-license --debug
$ apicup registry-upload portal portal-images-kubernetes_v2018.3.5.tgz 172.30.148.162:5000 --accept-license --debug
```

To check the content of registry use this command
```sh
oc get is
```

The command will return a result similar to the following:
```console
NAME                      DOCKER REPO                                                           TAGS                                                           UPDATED
analytics-client          docker-registry.default.svc:5000/apiconnect/analytics-client          2018-07-30-16-13-05-efcb07ada5d34635b3c85813e5c4c11347cf3a79   4 minutes ago
analytics-cronjobs        docker-registry.default.svc:5000/apiconnect/analytics-cronjobs        2018-06-25-21-53-38-32c0717d88ef569e2945fd161b1f7992c53552fd   3 minutes ago
analytics-ingestion       docker-registry.default.svc:5000/apiconnect/analytics-ingestion       2018-07-30-16-06-34-f9285d9d2af3919ceb968c16122690fbfca4c869   4 minutes ago
analytics-mq-kafka        docker-registry.default.svc:5000/apiconnect/analytics-mq-kafka        2018-07-30-16-06-11-4bea6208d4fc7ad2cc76f8c3aa0fd5d11c7b8651   4 minutes ago
analytics-mq-zookeeper    docker-registry.default.svc:5000/apiconnect/analytics-mq-zookeeper    2018-07-30-16-06-11-4bea6208d4fc7ad2cc76f8c3aa0fd5d11c7b8651   4 minutes ago
analytics-proxy           docker-registry.default.svc:5000/apiconnect/analytics-proxy           2018-07-30-13-40-45-2018.3-0-g42a4544                          8 minutes ago
analytics-storage         docker-registry.default.svc:5000/apiconnect/analytics-storage         2018-07-30-16-06-41-3ebdab1ce45e2df4d20c872cd1ae4fc60a4195a2   3 minutes ago
apim                      docker-registry.default.svc:5000/apiconnect/apim                      2018.3-91-80d569b                                              8 minutes ago
busybox                   docker-registry.default.svc:5000/apiconnect/busybox                   latest                                                         8 minutes ago
cassandra                 docker-registry.default.svc:5000/apiconnect/cassandra                 2018-07-16-14-28-13-296d0e231215976a3af6f58158797a4d08a19951   8 minutes ago
cassandra-health-check    docker-registry.default.svc:5000/apiconnect/cassandra-health-check    2018-03-20-00-46-39-master-0-gbb58e73                          8 minutes ago
cassandra-operator        docker-registry.default.svc:5000/apiconnect/cassandra-operator        2018-07-16-14-28-13-296d0e231215976a3af6f58158797a4d08a19951   8 minutes ago
client-downloads-server   docker-registry.default.svc:5000/apiconnect/client-downloads-server   2018-07-31-20-48-54-2018.3-0-gc54cabf                          8 minutes ago
juhu                      docker-registry.default.svc:5000/apiconnect/juhu                      2018-07-31-14-16-59-2018.3-0-ga44bda5                          8 minutes ago
ldap                      docker-registry.default.svc:5000/apiconnect/ldap                      2018.3-7-9f27c35                                               8 minutes ago
lur                       docker-registry.default.svc:5000/apiconnect/lur                       2018.3-48-453f476                                              8 minutes ago
openresty                 docker-registry.default.svc:5000/apiconnect/openresty                 alpine                                                         5 minutes ago
portal-admin              docker-registry.default.svc:5000/apiconnect/portal-admin              2018.3-3d8f608bfb28d1b6e50d1086cb863e15916b738e-219            2 minutes ago
portal-db                 docker-registry.default.svc:5000/apiconnect/portal-db                 2018.3-8297a6ed9ef3eaae670b1c5df3cfa765f2c04ea8-34             2 minutes ago
portal-dbproxy            docker-registry.default.svc:5000/apiconnect/portal-dbproxy            2018.3-8297a6ed9ef3eaae670b1c5df3cfa765f2c04ea8-34             2 minutes ago
portal-web                docker-registry.default.svc:5000/apiconnect/portal-web                2018.3-3d8f608bfb28d1b6e50d1086cb863e15916b738e-219            2 minutes ago
ui                        docker-registry.default.svc:5000/apiconnect/ui                        2018-07-31-20-24-34-e6175ec303effe7b8beea9a9e8bcc3ae8ba55f6b   8 minutes ago
```

### Create Docker registry secret

The registry secret will be used later during the installation, to access the registry. Create this now using the *kubectl* command:
```sh
kubectl create secret docker-registry <registry-secret-name> --docker-server=<registry-address:port> --docker-username=`oc whoami` --docker-password=`oc whoami -t` --docker-email=apic@apic.ibm -n apiconnect
```

The following shows the values that I used in my installation:
 ```sh
 kubectl create secret docker-registry apic-registry-secret --docker-server=172.30.148.162:5000 --docker-username=`oc whoami` --docker-password=`oc whoami -t` --docker-email=apic@apic.ibm -n apiconnect
 ```

### Cluster role binding

You will now use the following *yaml* to bind the *apiconnect* account to the cluster admin role:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: apiconnect-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: default
  namespace: apiconnect
```

Save the above content into the file **ClusterRoleBinding.yaml**, and then run:
```sh
oc create -f ClusterRoleBinding.yaml
```

### Dynamic storage provisioning

#### Introduction

IBM API Connect needs a storage system for persistently storing data (configuration, monitoring, analytics data... etc). I have found this to be the most critical step of the configuration on any Kubernetes implementation (I have tried on open source Kubernetes, IBM Cloud Private and OpenShift). 

There are two storage-related objects in Kubernetes: Volumes and Volume Claims. The Volume is a definition of the available storage, and the Volume Claim is a request for storage "sent" by the application running on Kubernetes.

When Kubernetes "receives" a Volume Claim, it searches for the available Volume with the specified properties (foremost the size of the volume). If there is such a Volume, Kubernetes binds it to the Volume Claim.

In the initial versions of Kubernetes it was the responsibility of the system administrator to configure Volumes in advance. The later versions of Kubernetes introduced an idea of dynamic volume provisioning. In this case, there is a special application (the "storage provider") that runs in a container in one of the Kubernetes pods.

One of the concepts behind a storage provider is the "storage class". The application that needs storage sends a Volume Claim with the specified storage class name. When Kubernetes receives such a Volume Claim, it checks the storage class name and then calls the storage provider that implements this storage class, asking it to create a volume. As a result, the volumes are created dynamically at runtime and there is no need to prepare them in advance. 

The above is a very simplified explanation; for more details see:
[Persistent Volumes](https://v1-8.docs.kubernetes.io/docs/concepts/storage/persistent-volumes/) and [Dynamic Provisioning and Storage Classes in Kubernetes](https://kubernetes.io/blog/2017/03/dynamic-provisioning-and-storage-classes-kubernetes/).

In the installation steps described here, I am using the following implementation of the dynamic provisioner: https://github.com/MaZderMind/hostpath-provisioner.
It is based on the [Kubernetes Incubator](https://github.com/kubernetes-incubator/external-storage/tree/master/docs/demo/hostpath-provisioner) project. This provisioner creates a volume in the specified directory of the **local file system** and therefore it is suitable for **demo installations** on **single-node Kubernetes configurations**.

For a **production installation** you should consider something like **Ceph** or **GlusterFS**, or a similar solution. The official API Connect documentation recommends Ceph. If you use GlusterFS there are possible performance problems in certain situations (ref: [Requirements for deploying API Connect into a Kubernetes runtime environment](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_reqs_Kubernetes.html)).
If you are installing on a customer's environment, I strongly recommend that you involve a local systems administrator. 

Theoretically, you can also use "static" Volumes. In this case, you have to prepare in advance an adequate number of volumes with the proper sizes, and you have to set '-' as the storage class name in the API Connect subsystems installation properties (see below in this document).

#### Setup

Prepare the following yaml files (or copy them from the **[resources](https://github.ibm.com/srecko-janjic/apic-on-openshift/tree/master/resources)** directory of this GitHub repository.)

**hostpath-prov-SCC.yaml**
```yaml
kind: SecurityContextConstraints
apiVersion: v1
metadata:
  name: hostpath
allowPrivilegedContainer: true
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: RunAsAny
fsGroup:
  type: RunAsAny
supplementalGroups:
  type: RunAsAny
users:
- ibm
groups:
- my-admin-group
```

**hostpath-prov-ClusterRole.yaml**
```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: hostpath-provisioner
  namespace: apiconnect
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]

  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]

  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]

  - apiGroups: [""]
    resources: ["events"]
    verbs: ["list", "watch", "create", "update", "patch"]
```

**hostpath-prov-ClusterRoleBinding.yaml**
```yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: hostpath-provisioner
  namespace: apiconnect
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: hostpath-provisioner
subjects:
- kind: ServiceAccount
  name: default
  namespace: apiconnect
```

**hostpath-prov-Deployment.yaml**
```yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: hostpath-provisioner
  labels:
    k8s-app: hostpath-provisioner
  namespace: apiconnect 
spec:
  replicas: 1
  revisionHistoryLimit: 0
  selector:
    matchLabels:
      k8s-app: hostpath-provisioner
  template:
    metadata:
      labels:
        k8s-app: hostpath-provisioner
    spec:
      containers:
        - name: hostpath-provisioner
          image: mazdermind/hostpath-provisioner:latest
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName

            - name: PV_DIR
              value: /var/kubernetes

            - name: PV_RECLAIM_POLICY
              value: Retain

          volumeMounts:
            - name: pv-volume
              mountPath: /var/kubernetes
      volumes:
        - name: pv-volume
          hostPath:
            path: /var/kubernetes
```

**hostpath-prov-StorageClass.yaml**
```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: hostpath-provisioner
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: hostpath
```

>**Important:** Note the class name used throughout the above (**hostpath-provisioner**). You will need it later.

Prepare the provisioner root directory
```sh
mkdir /var/kubernetes
```

Set permissions for the provisioner root directory:
```sh
chmod 777 /var/kubernetes
chcon -Rt svirt_sandbox_file_t /var/kubernetes
```

>**VERY IMPORTANT**: The permissions granted above are probably not recommended for a production environment. However, you are not likely to use the hostpath provisioner in a production environment anyway.
>
>If the installation of the management subsystem (described later in this document) hangs and never completes, check the status of Persistent Volume Claims:
>```sh
>kubectl get pvc -n apiconnect
>```
>If Persistent Volume Claims exist, but they remain in the "pending" state, the most likely cause of this problem are the permissions of the provisioner directory.

#### Run the provisioner configuration

Create the Security Context Constraint:
```sh
oc create -f hostpath-prov-SCC.yaml
oc patch scc hostpath -p '{"allowHostDirVolumePlugin": true}'
oc adm policy add-scc-to-group hostpath system:authenticated
```

Create ClusterRole:
```sh
oc create -f hostpath-prov-ClusterRole.yaml
```

Create ClusterRoleBinding:
```sh
oc create -f hostpath-prov-ClusterRoleBinding.yaml
```

Create Deployment:
```sh
oc create -f hostpath-prov-Deployment.yaml
```

Wait until the deployment has completed. Watch the status using this command:
```sh
oc rollout status deployment hostpath-provisioner
```

The response must be:
```console
deployment "hostpath-provisioner" successfully rolled out
```

Create StorageClass:
```sh
oc create -f hostpath-prov-StorageClass.yaml
```

### Helm and Tiller

Helm and Tiller must be installed in the OpenShift environment. If you are working in a customer's environment, you will need to check with their system administrator. Otherwise, use the instructions given here.  

Create a separate OpenShift project for Tiller:
```sh
oc new-project tiller
``` 

Define an environment variable for the Tiller namespace:
```sh
export TILLER_NAMESPACE=tiller
``` 

To permanently store it, paste that entire line into *bash_profile*
```sh
vi ~/.bash_profile
```

Install the Helm client (I tested this with version 2.9.0 from https://github.com/kubernetes/helm/releases/tag/v2.9.0 )
```sh
curl -s https://storage.googleapis.com/kubernetes-helm/helm-v2.9.0-linux-amd64.tar.gz | tar xz
``` 

Make the helm command available from everywhere by adding it to *PATH*. Or you could move it to */usr/bin* thus:
```sh
cd linux-amd64
mv ./helm /usr/bin/helm
```

Initialize the Helm client:
```sh
helm init --client-only
```

A response similar to the following should appear:
```console
Creating /root/.helm 
Creating /root/.helm/repository 
Creating /root/.helm/repository/cache 
Creating /root/.helm/repository/local 
Creating /root/.helm/plugins 
Creating /root/.helm/starters 
Creating /root/.helm/cache/archive 
Creating /root/.helm/repository/repositories.yaml 
Adding stable repo with URL: https://kubernetes-charts.storage.googleapis.com 
Adding local repo with URL: http://127.0.0.1:8879/charts 
$HELM_HOME has been configured at /root/.helm.
Not installing Tiller due to 'client-only' flag having been set
Happy Helming!	
```

Install the Tiller server:
```sh
oc process -f https://github.com/openshift/origin/raw/master/examples/helm/tiller-template.yaml -p TILLER_NAMESPACE="${TILLER_NAMESPACE}" -p HELM_VERSION=v2.9.0 | oc create -f -
```

Wait until the Tiller server is up and running. You can check if it is ready with the command:
```sh
oc rollout status deployment tiller
```

The following response should appear when Tiller server is ready:
```console
deployment "tiller" successfully rolled out
```

Verify communication between Helm and Tiller using the following command (information about both the client component and the server component should appear):
```sh
helm version
```

For final verification, run the following command, which should complete without errors:
```sh
helm list
```

>**VERY IMPORTANT**: It appears that the Tiller service account must have the cluster admin role, otherwise the API Connect installation will hang. If, during the installation of the management subsystem, you experience an infinite repetition of the message *"Wait for CRD cassandraclusters.apic.ibm.com to establish..."*, this is most likely the cause.
>
>Run this now (all on one line) to prevent those problems later:
>```sh
>oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:tiller:tiller
>```
>
>The above is good enough for a demonstration environment. Something more sophisticated should be implemented for a production environment.

During the Tiller installation you moved to another project. Return to the *apiconnect* project now using:
```sh
oc project apiconnect
```

### Grant permission to all the service accounts in the target namespace

This is one of the pre-installation requirements specified by the IBM API Connect [documentation](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_reqs_Kubernetes.html)
```sh
oc adm policy add-scc-to-group anyuid system:serviceaccounts:apiconnect
```

### Create an installation project

Prepare an empty directory and run project initialization as follows. This will create an empty version of the **apiconnect-up.yaml** file in the selected directory.
```sh
mkdir myProject
cd myProject
apicup init
```

### Install management subsystem

Run the *apicup* commands shown below to set up parameters for the management subsystem.

>**NOTE**: I have shown, in the commands below, some illustrative values (IP addresses and so on) which are specific to my installation. Don't forget to change these to reflect the values in your own environment.
>
>**Some additional remarks:**
>
>* For the endpoint definitions, I am using domain wildcards. The endpoint format is therefore: **\<endpoint_name\>.\<server_ip\>.nip.io**.
>* The registry address is the one that you  obtained previously (see the step "Login to the OpenShift's Docker registry" above).
>* The registry secret name is also the one that you created previously (see above).
>* The storage class name is the one that you defined during the hostpath provisioner setup. Change this if you are using a different solution for dynamic storage. If you are using traditional "static" Kubernetes volumes, this should be '-'.
>* The volume sizes shown in my example are extremely small. Please refer to the [API Connect documentation](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_Kubernetes.html) for the values recommended for production.     
>* The ingress type is **route**, as required for OpenShift by API Connect documentation (refer to the [APIC Knowledge Center](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_reqs_Kubernetes.html)).

The first command creates the subsystem definition in the **apiconnect-up.yaml** file:
```sh
apicup subsys create mgmt management --k8s
```
Where **mgmt** is the name of the management component configuration.

The other commands define the parameters of the management subsystem - **if you also use nip.io, please correct the enpoints to include the IP adress of the master node of your OpenShift cluster**:
```sh
apicup endpoints set mgmt platform-api platform.10.101.192.18.nip.io
apicup endpoints set mgmt api-manager-ui manager.10.101.192.18.nip.io
apicup endpoints set mgmt cloud-admin-ui cloud.10.101.192.18.nip.io 
apicup endpoints set mgmt consumer-api consumer.10.101.192.18.nip.io 
apicup subsys set mgmt registry 172.30.148.162:5000
apicup subsys set mgmt namespace apiconnect
apicup subsys set mgmt registry-secret apic-registry-secret
apicup subsys set mgmt cassandra-max-memory-gb 5 	
apicup subsys set mgmt cassandra-cluster-size 1
apicup subsys set mgmt cassandra-volume-size-gb 10
apicup subsys set mgmt storage-class hostpath-provisioner  
apicup subsys set mgmt mode dev
apicup subsys set mgmt ingress-type route
apicup subsys set mgmt portal-base-uri http://portal.10.101.192.18.nip.io
``` 

*Note: After the subsystem definition is created, it would be possible to open the **apiconnect-up.yaml** file in editor and change the parameters. Take a special care if you decide to do that.* 

***Run the installation of management subsystem:***

After the subsystem parameters are prepared, you can start the installation using the command:
```sh
apicup subsys install mgmt --debug
``` 

>**NOTE:** As an alternative, instead of running install command directly, you can first prepare the helm chart and the configuraion files for the inspection and review in a subdirectory (in this case **mgmt-out**):
>```sh
>apicup subsys install mgmt --out mgmt-out
>```
>and then use this subdirectory for the actual installation:
>```sh
>apicup subsys install mgmt --plan-dir ./mgmt-out
>```
>

The above could take some time to complete; please be patient.

When installation completes, you can verify the result by listing created Kubernetes objects using **oc** or **kubectl** commands. When you run those commands, make sure that you are in the *apiconnect* project; navigate to the project with **oc project apiconnect** or add **-n appiconnect** at the end of each command.

>**NOTE:** When you list the pods, you may notice that some of them are in *Init* or *ContainerCreating* state. You should wait for a few more minutes that the Kubernetes processes settle down. After that, you will see the results similar to the below examples. All pods should reach the state where READY is "1/1" and STATUS is "Running". The exceptions are pods with the STATUS "Completed". Those are pods which host jobs and are executed only once.

List pods:
```sh
oc get pods
```

```console
NAME                                                         READY     STATUS      RESTARTS   AGE
hostpath-provisioner-bb9cd947-5pktq                          1/1       Running     4          3d
r31f4a26f5e-a7s-proxy-7864b8cf97-zx6jr                       1/1       Running     0          1h
r31f4a26f5e-apiconnect-cc-0                                  1/1       Running     0          1h
r31f4a26f5e-apiconnect-cc-cassandra-stats-1536575400-fbmvt   0/1       Completed   0          24m
r31f4a26f5e-apim-schema-init-job-6kns8                       0/1       Completed   0          1h
r31f4a26f5e-apim-v2-7758b4f948-w8mmh                         1/1       Running     0          1h
r31f4a26f5e-client-dl-srv-77fccc469b-k4mkq                   1/1       Running     0          1h
r31f4a26f5e-juhu-86dc669cc9-ns5zb                            1/1       Running     0          1h
r31f4a26f5e-ldap-7d59b4855c-67mj5                            1/1       Running     0          1h
r31f4a26f5e-lur-schema-init-job-hdsgz                        0/1       Completed   0          1h
r31f4a26f5e-lur-v2-54c8fbdccd-klk4v                          1/1       Running     0          1h
r31f4a26f5e-ui-d855c94cd-c8qdh                               1/1       Running     0          1h
r5d88581ca1-cassandra-operator-6d56d48b5c-r96g6              1/1       Running     0          1h
```

List deployments:
```sh
oc get deployments
```

```console
NAME                             DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
hostpath-provisioner             1         1         1            1           3d
r31f4a26f5e-a7s-proxy            1         1         1            1           1h
r31f4a26f5e-apim-v2              1         1         1            1           1h
r31f4a26f5e-client-dl-srv        1         1         1            1           1h
r31f4a26f5e-juhu                 1         1         1            1           1h
r31f4a26f5e-ldap                 1         1         1            1           1h
r31f4a26f5e-lur-v2               1         1         1            1           1h
r31f4a26f5e-ui                   1         1         1            1           1h
r5d88581ca1-cassandra-operator   1         1         1            1           1h
```

List the stateful sets
```sh
oc get sts
```

```console
NAME                                  DESIRED   CURRENT   AGE
r31f4a26f5e-apiconnect-cc             1         1         2h
```

List services:
```sh
oc get services
```

```console
NAME                                          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)               AGE
r31f4a26f5e-a7s-proxy                         ClusterIP   172.30.238.172   <none>        8084/TCP              1h
r31f4a26f5e-apiconnect-cc                     ClusterIP   None             <none>        9042/TCP              1h
r31f4a26f5e-apim                              ClusterIP   172.30.100.161   <none>        3003/TCP,3006/TCP     1h
r31f4a26f5e-client-dl-srv                     ClusterIP   172.30.210.27    <none>        8443/TCP              1h
r31f4a26f5e-juhu                              ClusterIP   172.30.73.176    <none>        2000/TCP,2001/TCP     1h
r31f4a26f5e-ldap                              ClusterIP   172.30.207.67    <none>        3007/TCP              1h
r31f4a26f5e-lur                               ClusterIP   172.30.203.195   <none>        3004/TCP              1h
r31f4a26f5e-ui                                ClusterIP   172.30.186.61    <none>        8443/TCP              1h
r5d88581ca1-cassandra-operator                ClusterIP   172.30.228.81    <none>        1770/TCP              1h
```

List the persistent volume claims:
```sh
oc get pvc
```

```console
NAME                                   STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS           AGE
pv-claim-r31f4a26f5e-apiconnect-cc-0   Bound     pvc-8cbdd0ca-b4dd-11e8-bf56-005056bf130b   10Gi       RWO            hostpath-provisioner   1h
```

### Verification and the initial configuration of the management subsystem

You can check if the management subsystem works, **without** waiting until all the subsystems are installed. When you see that all the pods (deployments) are up and running, you can open the **Cloud Management Console** in your browser using the URL that you specified for the **cloud-admin-ui** in the installation yaml. 

As an illustration, this was the URL in my case; use the appropriate IP address for your environment:
```console
https://cloud.10.101.192.18.nip.io/admin
```

Login with the default username and password:
```console
Username: admin
Password: 7iron-hide
```

<img src="/images/01-cm-login.png">

Change the password when prompted to do so - and remember the new password because you will need it later.
<img src="/images/02-cm-change-password.png">
<img src="/images/03-cm-account-updated.png">

***Configure email server and notification***

You will need an SMTP server for the cloud management settings.

If you cannot use a real SMTP server, one of the options is that you use FakeSMTP. FakeSMTP will act like an SMTP server, and will show you e-mails that you generate inside API Connect, but it will not send e-mail anywhere.

Download FakeSMTP from: [http://nilhcem.com/FakeSMTP/download.html](http://nilhcem.com/FakeSMTP/download.html). Unzip it, and  then run the *jar* file thus:
```sh
java -jar fakeSMTP-2.0.jar -o ./emails/ -b -s -p 2525 &
``` 

where *emails* is a directory used to store the mails and 2525 is the port on which the FakeSMTP server is listening. 

>**Note:** FakeSMTP needs Java. If you don't have it on your RedHat / CentOS server refer the following document: [https://www.digitalocean.com/community/tutorials/how-to-install-java-on-centos-and-fedora](https://www.digitalocean.com/community/tutorials/how-to-install-java-on-centos-and-fedora).

Once, when you have prepared a SMTP server, you can continue with the management subsystem configuration. Navigate back to the Cloud Management Console that you opened eralier (*https://cloud.10.101.192.18.nip.io/admin*)

Click on **Resources** on the left navigation panel, then select **Notifications** and click on **Create** button:
<img src="/images/11-notif-server-create.png">

Enter some **title** for the SMTP server, **IP address** (in our case the address of the node where FakeSMTP is running) and the **port** (in our case the port on which FakeSMTP is listening). Click on **Save** button:
<img src="/images/12-notif-server-data.png">
<img src="/images/13-notif-server-save.png">

Your SMTP server will appear on the list of email servers:
<img src="/images/14-notif-server-created.png">

Now click on the **Cloud Settings** selection on the left navigation panel, then select **Notifications** and click on **Edit** button:
<img src="/images/15-notif-settings-edit.png">

Enter the administrator's name, **email address**, select the SMTP server from the list (**checkbox**) and click on **Save**:
<img src="/images/16-notif-settings-save.png">

You will receive a confirmation that the settings are saved and they will appear on the Notifications panel:
<img src="/images/17-notif-settings-saved.png">

***Create provider organization***

Select to the **Provider Organizations** on the left navigation panel, click on **Add** and then **Create organization**:
<img src="/images/21-prov-org-create.png">

Enter some **title** for the organization and select **New User**
<img src="/images/22-prov-org-data-1.png">

Enter a **username**, **password** and other details for the **organization owner**. Remember the username and password, you will need it later to login to the *API Manager* console. Click on **Create**.
<img src="/images/23-prov-org-data-2.png">

You will receive a confirmation and the organization will appear on the list
<img src="/images/24-prov-org-created.png">

### Install gateway subsystem

Let's continue with the installation of other subsystems. The core of the API Connect solution is a gateway subsystem. It is implemented using IBM DataPower Gateway. 

The IBM DataPower Gateway for API Connect can be provided in these ways:
* physical appliance
* software implementation (for Ubuntu or RedHat Linux)
* virtual image (for VMWare)
* docker image

In our case, you will run the Docker image of DataPower, in a Kubernetes pod on the same OpenShift environment as the other components.

In the terminal window, navigate to the directory that you prepared earlier for the installation project (the directory where the *apiconnect-up.yaml* file exists):
```sh
cd /myProject
```

Run the following command to create a gateway subsystem definition in the **apiconnect-up.yaml** file:
```sh
apicup subsys create gw gateway --k8s
```
...were **gw** is the name of the gateway configuration.

Then run the following commands to prepare the installation parameters - **if you also use nip.io, please correct the enpoints to include the IP adress of the master node of your OpenShift cluster**:
```sh
apicup endpoints set gw api-gateway gw.10.101.192.18.nip.io 	
apicup endpoints set gw apic-gw-service gws.10.101.192.18.nip.io
apicup subsys set gw namespace apiconnect
apicup subsys set gw image-repository ibmcom/datapower
apicup subsys set gw image-tag "7.7.1"
apicup subsys set gw replica-count 1
apicup subsys set gw max-cpu 2
apicup subsys set gw max-memory-gb 5
apicup subsys set gw storage-class hostpath-provisioner
apicup subsys set gw mode dev
apicup subsys set gw ingress-type route
```

Similarly as for the management subsystem, I specified the ***ingress-type*** as ***route***, which is specific for the OpenShift environment (ref: [Requirements for deploying API Connect into a Kubernetes runtime environment](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_reqs_Kubernetes.html)).
I am also using ***nip.io*** domain wildcard for the endpoints and ***hostpath-provisioner*** storage class defined earlier.

>**NOTE:** I assume here that we are pulling the gateway image directly form the public Docker Hub on the Internet. This is defined with the parameter **image-repository**. The value **ibmcom/datapower** means that we pull the image described at [https://hub.docker.com/r/ibmcom/datapower/](https://hub.docker.com/r/ibmcom/datapower/). The parameter **image-tag** represents the version that we want to pull. It must be specified within double quotes. If you want to pull the latest version, simply put word "latest" (be sure that it is supported by your version of API Connect). You can find here the list of version tags: [https://hub.docker.com/r/ibmcom/datapower/tags/](https://hub.docker.com/r/ibmcom/datapower/tags/). 
>
>As an alternative to pulling image directly from the public Docker Hub, you can first upload it to the local OpenShift's docker registry and the use it similarly as images for other APIC subsystems.
>
>You have to be logged in to the OpenShift's docker registry. For the instructions, see the chapter ***"Login to the OpenShift's Docker registry"*** above in this document.
>
>Pull the IBM DataPower Gateway image from the public docker hub thus
>```sh
>docker pull ibmcom/datapower
>```
>
>Tag the image with the previously-determined OpenShift docker-registry service address and the namespace **apiconnect**:
>```sh
>docker tag ibmcom/datapower <registry-address:<port>/apiconnect/datapower-api-gateway:latest
>```
>
>In my case it was:
>```console
>docker tag ibmcom/datapower 172.30.148.162:5000/apiconnect/datapower-api-gateway:latest
>``` 
>
>Check images on local docker registry:
>```sh
>docker images | grep datapower
>```
>
>You should see in the list both the downloaded original and the newly tagged one (although in fact it is the same image >with two names).
>
>Push the image to OpenShift registry, using the docker-registry service address and port:
>```sh
>docker push <registry-address>:<port>/apiconnect/datapower-api-gateway:latest
>```
>
>This was my version of the above command:
>```console
>docker push 172.30.148.162:5000/apiconnect/datapower-api-gateway:latest
>``` 
>
>Check the registry content through the OpenShift web console, or with this command:
>```sh
>oc get is
>``` 
>
>You should see the image *datapower-api-gateway:latest* in the namespace *apiconnect*.
>
>If you prefer to use this approach instead of pulling image from the public docker hub, you also have to specify a different set of *apicup* command parameters.
>
>Instead of:
>```sh
>apicup subsys set gw image-repository ibmcom/datapower
>apicup subsys set gw image-tag "7.7.1"
>```
>
>Run
>```sh
>apicup subsys set gw registry 72.30.148.162:5000    # change this to the IP of your registry
>apicup subsys set gw registry-secret apic-registry-secret
>```
>

**Run the installation**:

Similarly as shown before for the management subsystem, you have two possibilities,
to run installation using directly the parameters in *apiconnect-up.yaml*: 
```sh
apicup subsys install gw --debug
```

...or to prepare first the configuration and helm files in a subdirectory, for example **gw-out**:
```sh
apicup subsys install gw --out gw-out
```

and run the installation using the content of this subdirectory:
```sh
apicup subsys install gw --plan-dir ./gw-out
```

When installation finishes and after the things settle down, you should see new Kubernetes objects created. They will contain **dynamic-gateway-service** in their names:

Pods:
```sh
oc get pods
```

<img src="/images/gw-pods.png">

Stateful sets:
```sh
oc get sts
```

<img src="/images/gw-sts.png">

Services:
```sh
oc get services
```

<img src="/images/gw-services.png">

### Verify gateway installation by accessing the DataPower command line interface
    
You can verify that DataPower is correctly installed by accessing its console (command line interface).

Because DataPower is now running in a Kubernetes pod, you will first have to "attach" (connect) to that pod. To do this, first identify the pod as follows (you must be in **apiconnect** project):
```sh
oc get pods
```

Find the pod whose name contains **dynamic-gateway-service**:

<img src="/images/gw-pods.png">

and attach to it using the following command:
```sh
kubectl attach pods rde5615f28a-dynamic-gateway-service-0 --stdin -n apiconnect
```

You will get the following response:
```console
Defaulting container name to dynamic-gateway-service.
Use 'kubectl describe pod/rde5615f28a-dynamic-gateway-service-0 -n apiconnect' to see all of the containers in this pod.
If you don't see a command prompt, try pressing enter.

Login: 
Password: 
```

Enter **admin/admin** for the username and password (this is the DataPower default).

You should see a screen that looks like this:
```console
Welcome to IBM DataPower Gateway console configuration. 
Copyright IBM Corporation 1999, 2018-2018 

Version: IDG.7.7.1.1 build 300826 on Jun 26, 2018 12:28:57 AM
Serial number: 0000001

idg# 20180711T110427.713Z [0x82400055][audit][info] : (SYSTEM:default:serial-port:*): Authenticating user (admin) - verifying password.
20180711T110427.713Z [0x82400056][audit][info] : (SYSTEM:default:serial-port:*): Authenticating user (admin) - checking domain restrictions.
20180711T110427.728Z [0x81000026][system][info] : User 'admin' logged into domain 'default'
20180711T110427.729Z [0x81000033][auth][notice] user(admin): User logged into 'default'.
.....
```

You are now in the standard DataPower command line interface (console).
This proves that DataPower is working and is accessible.

Enter **exit** to sign off the console.
    
### Register gateway service

After the gateway is installed, we have to add it to the API Connect cloud topology.

You will need the URL representing the gateway's endpoint. To find this, switch to the command line console and run:
```sh
kubectl get services -n apiconnect | grep dynamic-gateway-service-ingress
```
Note the service endpoint.

<img src="/images/31-gateway-ingress.png">

Switch to the Cloud Management Console (**use the appropriate IP address for your environment**):
```console
https://cloud.10.101.192.18.nip.io/admin
```

Click on the **Topology** selection on the left navigation panel and then click on **Register Service** button: 
<img src="/images/32-gateway-reg-start.png">

Select the service type. In our case it is a **"Classic" DataPower Gateway**. Please note that there could be a newer API Gateway already available. Check the documentation and the version that you pulled from the Docker Hub.
<img src="/images/33-gateway-reg-type.png">

Give some **title** to the gateway service. For the **Endpoint** use the **service IP** that you determined before with **https** protocol and **port 3000**:
<img src="/images/34-gateway-reg-data-1.png">

For the **API Endpoint Base** use the same **service IP** that you determined before with **https** protocol and **port 9443**. Click on **Save** button:
<img src="/images/35-gateway-reg-data-2.png">

You will receive a confirmation message and the gateway service will appear on the list of registered services:
<img src="/images/36-gateway-reg-completed.png">

### Default gateway for Sandbox catalog

Navigate in your browser to the URL determined by the **api-manager-ui** endpoint parameter defined in **apiconnect-up.yaml** when you installed the management subsystem.
In my case it looks like this:
```sh
https://manager.10.101.192.18.nip.io/manager
```

Login with the username and password of the **owner** of the **provider organization** that you defined earlier during the management subsystem configuration:
<img src="/images/41-apim-login.png">

The API Manager page opens:
<img src="/images/42-apim-manage.png">

Click on **Manage** selection on the left navigation panel and then click on the **catalog**:
<img src="/images/43-apim-cat-select.png">

Select the **Settings** option on the catalog's left navigation panel, then select **Gateway Services** and click on **Edit** button:
<img src="/images/44-apim-cat-settings-gw.png">

Select the gateway service from the list (**checkbox**), and then click on **Save**:
<img src="/images/45-apim-cat-gw-select.png">

You will get a confirmation message and the service will appear on the list:
<img src="/images/46-apim-cat-gw-assigned.png">

### Create a simple example to verify the configuration

You can now create a simple example to verify that your configuration works. This can be done now, before you setup the analytics and portal subsystems.

You could use the tutorial from the Knowledge Center here: [https://www.ibm.com/support/knowledgecenter/en/SSMNED_2018/com.ibm.apic.apionprem.doc/tutorial_apionprem_apiproxy.html](https://www.ibm.com/support/knowledgecenter/en/SSMNED_2018/com.ibm.apic.apionprem.doc/tutorial_apionprem_apiproxy.html)

### Install analytics subsystem

Similarly as with the previous two subsystems, switch to the terminal window and navigate to your installation project directory where **apiconnect-up.yaml** is located. For example:
```sh
cd /myProject
```

Create an analytics subsystem definition in **apiconnect-up.yaml**:
```sh
apicup subsys create a7s analytics --k8s
```

...where **a7s** is the name that we gave to the configuration.

Set the parameters. Again, I am using **nip.io** domain wildcard for the endpoints, adapt this to contain the IP address of your OpenShift master node. Also correct the registry address to reflect your configuration. The storage sizes are quite small in my case, because I was running everything on one machine. Please refer APIC [documentation](https://www.ibm.com/support/knowledgecenter/SSMNED_2018/com.ibm.apic.install.doc/tapic_install_Kubernetes.html) for more details.
```sh
apicup endpoints set a7s analytics-ingestion analytics-ingestion.10.101.192.18.nip.io
apicup endpoints set a7s analytics-client analytics-client.10.101.192.18.nip.io
apicup subsys set a7s registry 172.30.148.162:5000
apicup subsys set a7s namespace apiconnect
apicup subsys set a7s registry-secret apic-registry-secret
apicup subsys set a7s coordinating-max-memory-gb 6
apicup subsys set a7s data-max-memory-gb 8
apicup subsys set a7s data-storage-size-gb 20
apicup subsys set a7s master-max-memory-gb 8
apicup subsys set a7s master-storage-size-gb 1
apicup subsys set a7s storage-class hostpath-provisioner
apicup subsys set a7s mode dev
apicup subsys set a7s ingress-type route
```

And, finally, **run the installation**.
Similarly as before, you have two options,
to run using the parameters directly from **apiconnect-up.yaml**:
```sh
apicup subsys install a7s --debug
```

or prepare a subdirectory with the helm and configuration files:
```sh
apicup subsys install a7s --out a7s-out
```

and then run installation using this subdirectory:
```sh
apicup subsys install a7s --plan-dir ./a7s-out
``` 

>**NOTE:** The installation and creation of the analytics Kubernetes components is quite demanding process. Please be patient and wait that all pods are up and running (or completed). Some of the pods can stay for very long time in the Init or ContainerCreating state, or can even temporary show errors.   

When installation is completed, you will see the following new Kubernetes object:

Pods:
```sh
oc get pods
```

<img src="/images/a7s-pods.png">

Deployments:
```sh
oc get deployments
```

<img src="/images/a7s-deployments.png">

Stateful sets:
```sh
oc get sts
```

<img src="/images/a7s-sts.png">

Services:
```sh
oc get services
```

<img src="/images/a7s-services.png">

Persistent volume claims (must be in the Bound state):
```sh
oc get pvc
```

<img src="/images/a7s-pvc.png">

### Register analytics service

We have to register the analytics service in API Connect cloud topology. Switch to the cloud management console:
<img src="/images/61-cm-console.png">

Select **topology** and click on the **Register Service** button:
<img src="/images/62-analytics-reg-start.png">

Select **Analytics** service type:
<img src="/images/63-analytics-reg-type.png">

Give some **title** for the service. For the **Endpoint**, construct the URL from the value that you defined for the **analytics-client** parameter in the **apiconnect-up.yaml** file with the **https** protocol:
<img src="/images/64-analitycs-reg-data-1.png">

Click on **Save**:
<img src="/images/65-analytics-reg-data-2.png">

You will receive a confirmation message and the service will appear on the list:
<img src="/images/66-analytics-reg-completed.png">

### Assign analytics service to the gateway service

Select the **topology** again. Click on **Associate Analytics Service** link in the gateway service row:
<img src="/images/71-gw-analytics-start.png">

Select the analytics service (**checkbox**) and click on the **Associate** button:
<img src="/images/72-gw-analytics-select.png">

The analytics service title will appear in the gateway service row:
<img src="/images/73-gw-analytics-completed.png">

### Install portal subsystem

Navigate once again to the installation project directory:
```sh
cd /myProject
```

Create portal subsystem definition:
```sh
apicup subsys create portal portal --k8s
```

I selected **portal** as the name of the configuration.

Set parameters. Change the endpoints and the registry address to appropriate to your environment:
```sh
apicup endpoints set portal portal-admin padmin.10.101.192.18.nip.io
apicup endpoints set portal portal-www  portal.10.101.192.18.nip.io
apicup subsys set portal registry 172.30.148.162:5000
apicup subsys set portal namespace apiconnect
apicup subsys set portal registry-secret apic-registry-secret
apicup subsys set portal www-storage-size-gb 5
apicup subsys set portal backup-storage-size-gb 5
apicup subsys set portal db-storage-size-gb 5
apicup subsys set portal db-logs-storage-size-gb 2
apicup subsys set portal storage-class hostpath-provisioner
apicup subsys set portal ingress-type route
apicup subsys set portal mode dev
```

**Run the installation**

Similarly as before, you have two options,
to run directly:
```sh
apicup subsys install portal --debug
```

or to first prepare subdirectory with the configuration and helm charts:
```sh
apicup subsys install portal --out portal-out
```

and then run, using it:
```sh
apicup subsys install portal --plan-dir ./portal-out
```

>**NOTE:** You may notice the following problem after the installation;
>when you list the pods, you could see that two of portal pods are in the **ImagePullBackOff** state. Like this:
>```console
>r2484482d49-apic-portal-db-0                                 0/2       ImagePullBackOff   0         
>r2484482d49-apic-portal-nginx-7f8bd6bc4d-ng5hc               1/1       Running            0         
>r2484482d49-apic-portal-www-0                                0/2       ImagePullBackOff   0
>```
>
>If this happens to you, do the following:
>
>Export the configuration of the stateful set which controls the first pod to a yaml file (note that the stateful set has the same name as the pod, but without extension "-0" at the end):
>```sh
>oc get sts r2484482d49-apic-portal-db -o yaml > apic-portal-db.yaml
>```
>
>Open this yaml file in editor, for example:
>```sh
>vi apic-portal-db.yaml
>```
>
>Find occurrences of the **imagePullPolicy** property (there are two of them) and change the value **Always** to **IfNotPresent**. Be very careful when editing to not, by accident, spoil something. Save the file. 
>
>Replace the existing stateful set with the new configuration:
>```sh
>oc replace sts r2484482d49-apic-portal-db -f apic-portal-db.yaml
>```
>
>Repeat the same with other stateful set.
>
>Export:
>```sh
>oc get sts r2484482d49-apic-portal-www -o yaml > apic-portal-www.yaml
>```
>
>Edit yaml file:
>```sh
>vi apic-portal-www.yaml
>```
>
>Find all occurrences of **imagePullPolicy** and replace **Always** with **IfNotPresent**. Save the file.
>
>Replace the stateful set:
>```
>oc replace sts r2484482d49-apic-portal-www -f apic-portal-www.yaml
>```
>
>After few seconds the problematic pods should start correcting themselves and finally they will achieve the **Running** state.         

This is the state of the key Kubernetes objects after the installation is completed.

Pods:
```sh
oc get pods
``` 

<img src="/images/portal-pods.png">

Deployments:
```sh
oc get deployments
```

<img src="/images/portal-pods.png">


Stateful sets:
```sh
oc get sts
```

<img src="/images/portal-pods.png">

Services:
```sh
oc get services
```

<img src="/images/portal-services.png">

Persistent volume claims:
```sh
oc get pvc
```

<img src="/images/portal-pvc.png">

### Register portal service

Finally, we have to register the portal service. Switch once again to the Cloud Management Console:
<img src="/images/51-cm-console.png">

Select **Topology** and click on **Register Service**:
<img src="/images/52-portal-reg-start.png">

Select the Portal service type:
<img src="/images/53-portal-reg-type.png">

Give some **title** to the service. For the **Endpoint**, combine the property **portal-admin** that you defined in **apiconnect-up.yaml** with **https** protocol:
<img src="/images/54-portal-reg-data-1.png">

For the **Portal Website URL** use property **portal-www** from **apiconect-up.yaml**, plus **https** protocol. Click on **Save**:
<img src="/images/55-portal-reg-data-2.png">

You will receive a confirmation message and portal will appear on the list of services:
<img src="/images/56-portal-reg-completed.png">