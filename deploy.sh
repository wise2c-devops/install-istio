#!/bin/bash
set -e

tar zxvf file/helm-linux-amd64.tar.gz --strip-components=1 -C /tmp/
mv /tmp/helm /usr/local/bin/helm
chmod +x /usr/local/bin/helm

MyImageRepositoryIP=`cat components.txt |grep "Harbor Address" |awk '{print $3}'`
MyImageRepositoryProject=library
IstioVersion=`cat components.txt |grep "Istio Version" |awk '{print $3}'`

######### Push images #########
for file in $(cat file/images-list.txt); do docker tag $file $MyImageRepositoryIP/$MyImageRepositoryProject/${file##*/}; done

echo 'Images taged.'

for file in $(cat file/images-list.txt); do docker push $MyImageRepositoryIP/$MyImageRepositoryProject/${file##*/}; done

echo 'Images pushed.'

######### Update deploy yaml files #########
cd file
rm -rf istio-$IstioVersion
tar zxvf istio-$IstioVersion-origin.tar.gz
cd istio-$IstioVersion/install/kubernetes
sed -i "s/docker.io\/istio/$MyImageRepositoryIP\/$MyImageRepositoryProject/g" $(grep -lr "docker.io/istio" ./ |grep .yaml)
sed -i "s/docker.io\/prom/$MyImageRepositoryIP\/$MyImageRepositoryProject/g" $(grep -lr "docker.io/prom" ./ |grep .yaml)
sed -i "s/docker.io\/jaegertracing/$MyImageRepositoryIP\/$MyImageRepositoryProject/g" $(grep -lr "docker.io/jaegertracing" ./ |grep .yaml)
sed -i "s/grafana\/grafana/$MyImageRepositoryIP\/$MyImageRepositoryProject\/grafana/g" $(grep -lr "grafana/grafana" ./ |grep .yaml)
sed -i "s/quay.io\/kiali/$MyImageRepositoryIP\/$MyImageRepositoryProject/g" $(grep -lr "quay.io/kiali" ./ |grep .yaml)
cd ../../

# Istio init deploy
kubectl create ns istio-system
helm install install/kubernetes/helm/istio-init -g --namespace istio-system

set +e
######### Deploy Istio #########
# We need to verify that all 23 Istio CRDs were committed to the Kubernetes api-server
printf "Waiting for Istio to commit custom resource definitions..."

until [ `kubectl get crds |grep 'istio.io\|certmanager.k8s.io' |wc -l` -eq 23 ]; do printf "."; done

crdresult=""
for ((i=1; i<=23; i++)); do crdresult=${crdresult}"True"; done

until [ `for istiocrds in $(kubectl get crds |grep 'istio.io\|certmanager.k8s.io' |awk '{print $1}'); do kubectl get crd ${istiocrds} -o jsonpath='{.status.conditions[1].status}'; done` = $crdresult ]; do sleep 1; printf "."; done

echo 'Phase1 done!'
set -e

helm install install/kubernetes/helm/istio -g --namespace istio-system --set gateways.istio-ingressgateway.type=NodePort --values install/kubernetes/helm/istio/values-istio-demo.yaml

echo 'Phase2 done!'

cd ../

kubectl apply -f template/kiali-service.yaml
kubectl apply -f template/jaeger-service.yaml
kubectl apply -f template/prometheus-service.yaml
kubectl apply -f template/grafana-service.yaml

echo 'NodePorts are set for services.'
