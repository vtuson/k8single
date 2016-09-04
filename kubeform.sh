#!/bin/bash

IPMARKER="PUBLICIP"
NODE_IP=$1
KEYSDIR="$HOME/keys"
K8VERSION="v1.3.4_coreos.0"

echo "setting k8s in $NODE_IP"

sudo mkdir -p /etc/systemd/system/etcd2.service.d
sudo mkdir -p /etc/kubernetes/manifests
sudo mkdir -p /etc/kubernetes/ssl
sudo mkdir -p /etc/flannel/
sudo mkdir -p /etc/systemd/system/flanneld.service.d
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo mkdir -p /opt/bin/
mkdir -p $KEYSDIR

sed "s/PUBLICIP/$NODE_IP/g" files/40-listen-address.conf  > /tmp/40-listen-address.conf 
sudo mv /tmp/40-listen-address.conf  /etc/systemd/system/etcd2.service.d/40-listen-address.conf

echo "starting etcd..."
sudo systemctl start etcd2
sudo systemctl enable etcd2


echo "creating keys in $KEYSDIR"
openssl genrsa -out $KEYSDIR/ca-key.pem 2048
openssl req -x509 -new -nodes -key $KEYSDIR/ca-key.pem -days 10000 -out $KEYSDIR/ca.pem -subj "/CN=kube-ca"


sed "s/PUBLICIP/$NODE_IP/g" files/openssl.cnf > $KEYSDIR/openssl.cnf
openssl genrsa -out  ${KEYSDIR}/apiserver-key.pem 2048
openssl req -new -key  $KEYSDIR/apiserver-key.pem -out  $KEYSDIR/apiserver.csr -subj "/CN=kube-apiserver" -config  $KEYSDIR/openssl.cnf
openssl x509 -req -in  $KEYSDIR/apiserver.csr -CA  $KEYSDIR/ca.pem -CAkey  $KEYSDIR/ca-key.pem -CAcreateserial -out  $KEYSDIR/apiserver.pem -days 365 -extensions v3_req -extfile  $KEYSDIR/openssl.cnf 
openssl genrsa -out $KEYSDIR/admin-key.pem 2048
openssl req -new -key $KEYSDIR/admin-key.pem -out $KEYSDIR/admin.csr -subj "/CN=kube-admin"
openssl x509 -req -in $KEYSDIR/admin.csr -CA $KEYSDIR/ca.pem -CAkey $KEYSDIR/ca-key.pem -CAcreateserial -out $KEYSDIR/admin.pem -days 365

sudo cp $KEYSDIR/ca.pem /etc/kubernetes/ssl/
sudo cp $KEYSDIR/apiserver.pem /etc/kubernetes/ssl/
sudo cp $KEYSDIR/apiserver-key.pem /etc/kubernetes/ssl/

sudo chmod 600 /etc/kubernetes/ssl/*-key.pem
sudo chown root:root /etc/kubernetes/ssl/*-key.pem

sed "s/PUBLICIP/$NODE_IP/g" files/options.env  > /tmp/options.env
sudo mv /tmp/options.env  /etc/flannel/
sudo cp  files/40-ExecStartPre-symlink.conf /etc/systemd/system/flanneld.service.d/

sed "s/PUBLICIP/$NODE_IP/g" files/kubelet.service | sed "s/K8VERSION/$K8VERSION/g" > /tmp/kubelet.service
sudo mv /tmp/kubelet.service  /etc/systemd/system/

sed "s/PUBLICIP/$NODE_IP/g" files/kube-apiserver.yaml > /tmp/kube-apiserver.yaml
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/

sudo cp files/kube-proxy.yaml /etc/kubernetes/manifests/
sudo cp files/kube-controller-manager.yaml /etc/kubernetes/manifests/
sudo cp files/kube-scheduler.yaml /etc/kubernetes/manifests/

sudo systemctl daemon-reload

echo "configuring etcd"
curl -s -X PUT -d "value={\"Network\":\"10.2.0.0/16\",\"Backend\":{\"Type\":\"vxlan\"}}" "http://$NODE_IP:2379/v2/keys/coreos.com/network/config"


echo "starting kubernetes"
sudo systemctl start kubelet
sudo systemctl enable kubelet

echo "waiting for api server to set up"

max=10
for (( i=0; i <= $max; ++i ))
do
   printf "."
   status=$(curl -s -w %{http_code} "http:/127.0.0.1:8080/version")
   if [ "${status}" != "000" ]; then
      break
      apiup=true
   fi
   sleep 30 
done

#curl -s -H "Content-Type: application/json" -XPOST -d'{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"kube-system"}}' "http://127.0.0.1:8080/api/v1/namespaces"

echo "install kubectl"
curl -s -O https://storage.googleapis.com/kubernetes-release/release/v1.3.4/bin/linux/amd64/kubectl
sudo mv kubectl /opt/bin
sudo chmod +x /opt/bin/kubectl

kubectl config set-cluster default-cluster --server=https://$NODE_IP --certificate-authority=$KEYSDIR/ca.pem 

kubectl config set-credentials default-admin --certificate-authority=$KEYSDIR/ca.pem --client-key=$KEYSDIR/admin-key.pem --client-certificate=$KEYSDIR/admin.pem 

kubectl config set-context default-system --cluster=default-cluster --user=default-admin
kubectl config use-context default-system
kubectl create -f files/dns.yml
kubectl get pods --all-namespaces
