
## To Start:
```
for i in cell-api-cont cell-c1-cont cell-c1-comp-01; do vagrant up $i; done
vagrant ssh cell-api-cont
sudo su -
bash /vagrant/create_net_run_instance_demo.sh
```

## To Stop:
```
for i in `vagrant status | grep running | awk {'print $1'}`; do vagrant destroy -f $i; done; sudo purge
```

[Currently Broke](http://stackoverflow.com/questions/25600226/error-failed-to-attach-interface-http-500-request-id-req-xxxx)
