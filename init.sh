#! /bin/bash

set -e

path=`dirname $0`

HelmVersion=`cat ${path}/components.txt |grep "Helm" |awk '{print $3}'`
IstioVersion=`cat ${path}/components.txt |grep "Istio" |awk '{print $3}'`

curl -o ${path}/file/helm-linux-amd64.tar.gz https://get.helm.sh/helm-v${HelmVersion}-linux-amd64.tar.gz
echo "=== helm binary package is saved successfully ==="
curl -L -o ${path}/file/istio-$IstioVersion-origin.tar.gz https://github.com/istio/istio/releases/download/$IstioVersion/istio-$IstioVersion-linux.tar.gz
echo "=== Istio source code packag is saved successfully ==="

cd ${path}/file/
tar zxf istio-$IstioVersion-origin.tar.gz
cat istio-$IstioVersion/install/kubernetes/istio-demo.yaml |grep "image:" |grep -v '\[\[' |grep -v '{' |awk -F':' '{print $2":"$3}' |awk -F "[\"\"]" '{print $2}' |awk '!a[$0]++{print}' > images-list.txt
#echo "istio/proxy_init:"${IstioVersion} >> images-list.txt
echo "ubuntu:xenial" >> images-list.txt

echo 'Images list for Istio:'
cat images-list.txt

for file in $(cat images-list.txt); do docker pull $file; done
echo 'Images pulled.'

docker save $(cat images-list.txt) -o istio-images-$IstioVersion.tar
echo 'Images saved.'

rm -rf istio-$IstioVersion
