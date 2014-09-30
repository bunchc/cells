sudo apt-get update && apt-get upgrade -y

echo root:vagrant | chpasswd
sudo sed -i "s/PermitRootLogin without-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
restart ssh

echo "
# CookbookHosts
172.16.0.101	cell-api-cont.lab
172.16.0.102	cell-c1-cont.lab
172.16.0.110	cell-c1-comp.lab
172.16.0.103	cell-c2-cont.lab
172.16.0.120	cell-c2-comp.lab" | sudo tee -a /etc/hosts

export MY_IP=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}')