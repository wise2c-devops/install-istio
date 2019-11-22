# Install Istio with Helm offline

**1. Fetch installation packages and images**

Execute the command as below on the server which can access internet.

```
bash init.sh
```

**2. Install Istio with Helm offline**

(1)Copy the whole folder "install-istio" to a K8s node with kubectl command.

(2)Modify the harbor address in the file "components.txt"

(3)Execute below commands:

```
cd install-istio
bash deploy.sh
```
