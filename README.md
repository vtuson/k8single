# k8single

Basic k8s setup for a Core OS single node with the aim to use for staging or CI deployments. Follows https://coreos.com/kubernetes/docs/latest/getting-started.html

Only tested in Azure, it requires a Core OS instance running, then connect to it and:
git clone https://github.com/vtuson/k8single.git k8
cd k8
./kubeform.sh [myip-address] --> ip associated to eth, you can find it using ifconfig

This will deploy k8 into a single scheduable node, it sets up kubectl in the node and deploys skydns add on.  

It also includes a busybox node file that can be deployed by:
kubectl create -f files/busybox

This might come useful to debug issues with the set up. To execute commands in busybox run:
kubectl exec busybox -- [command]

