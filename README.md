# kubeflow-aws-ami

This document explains the steps performed to build an AWS AMI with Kubeflow.

Kubeflow is installed on top of microk8s using juju on EC2 VM.

Steps are not automated at this point yet.

Disclaimer:
This is the first working version of this AMI.
There are many things to improve, I know.
Feel free to propose changes.

## Prerequisites

EC2 virtual machine t3.xlarge flavor with 80g of disk.
Files from this repository copied to the machine.

## Steps

1. **Prepare scripts**

Copy microk8s.sh script to the respective folder so that it launches automatically per everyboot:
```
$ sudo cp microk8s.sh /var/lib/cloud/scripts/per-boot/microk8s.sh
```
Copy hostname.sh script to the respective folder to change the instance name on first boot:
```
$ sudo cp hostname.sh /var/lib/cloud/scripts/per-instance/hostname.sh
```
Make scripts executable:
```
$ sudo chmod +x /var/lib/cloud/scripts/per-instance/hostname.sh

$ sudo chmod +x /var/lib/cloud/scripts/per-boot/microk8s.sh
```
Add hosts record:
```
$ echo "127.0.0.1   kubeflow-appliance" | sudo tee -a /etc/hosts
```
Copy conf file to increase max_user params:
```
$ sudo cp custom-inotify.conf /etc/sysctl.d/99-custom-inotify.conf
```
Set the hostname and reboot:
```
$ sudo hostnamectl set-hostname kubeflow-appliance

$ sudo reboot now
```
2. **Install required software**

Start with juju, microk8s and kubectl:
```
$ sudo snap install juju --classic

$ sudo snap install microk8s --classic --channel=1.26-strict/stable 

$ sudo snap install kubectl --classic
```
Configure microk8s:
```
$ mkdir -p ~/.kube

$ sudo usermod -a -G snap_microk8s ubuntu

$ sudo chown -R ubuntu ~/.kube

$ newgrp snap_microk8s

$ sudo microk8s enable dns storage ingress metallb:10.64.140.43-10.64.140.49
```
Save kube config (replace 172.31.24.91 with your actual instance IP):
```
$ microk8s config | sed 's/172.31.24.91/127.0.0.1/g' > ~/.kube/config
```
3. **Bootstrap juju and deploy Kubeflow**
```
$ mkdir -p /home/ubuntu/.local/share

$ juju bootstrap microk8s

$ juju add-model kubeflow

$ juju deploy kubeflow --trust  --channel=1.8/stable
```
4. **Configure Kubeflow auth**
```
$ juju config dex-auth public-url=http://10.64.140.43.nip.io

$ juju config oidc-gatekeeper public-url=http://10.64.140.43.nip.io

$ juju config dex-auth static-username=admin

$ juju config dex-auth static-password=password
```
5. **Wait for juju model to settle**

Takes about 30 minutes. 

Check juju and kubectl model status in the meanwhile.

All services should be green with no errors.
```
$ juju status

$ microk8s.kubectl get all -n kubeflow
```
6. **Confirm Kubeflow is functional**

Configure port forwarding on you local machine through instance:
```
$ sudo ssh -i appliance.pem -D 999 ubuntu@AWS_PUBLIC_IP
```
Configure socks5 on your local machine with the following params:

127.0.0.1 port 999

Access Kubeflow from local machine:
http://10.64.140.43.nip.io/dex/auth/

You should see Kubeflow login page.

Confirm login works with admin:password.

Apply ingress to be able to access Kubeflow later with port 80:
```
$ microk8s.kubectl apply -f ingress.yaml
```
7. **Create the AMI**

Remove the ssh key injected into the VM by you originally to login:
```
$ rm ./ssh/authorized_keys
```
Stop microk8s before creating AMI:
```
$ sudo microk8s stop
```
Shutdown the VM to ensure data integrity during AMI creation:

In AWS console:
```
$ aws ec2 stop-instances --instance-ids i-xxxxx

$ aws ec2 create-image --instance-id i-xxxxx --name "Kubeflow-version-1.8" --description "Kubeflow Appliance"
```
This process takes about 20 minutes or so.

After the snapshot is created you can create an instance using it with the same t3.xlarge size and 80g of disk.

Once the created instance is up it takes about 15 minutes for microk8s and services to come up.

Then you will be able to access Kubeflow directly with you instance public IP and port 80.

## Additional info

Kubeflow docs: https://charmed-kubeflow.io/docs/get-started-with-charmed-kubeflow

Juju docs: https://juju.is/docs

Microk8s docs: https://microk8s.io/docs
