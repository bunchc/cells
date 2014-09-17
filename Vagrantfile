# -*- mode: ruby -*-
# vi: set ft=ruby :

# Creates a 3 node cluster
nodes = {
  'cell-api-cont' => [1, 101],
  'cell-c1-cont' => [1, 102],
  'cell-c2-cont' => [1, 103],
  'cell-c1-comp' => [1, 110], # Compute nodes for Cell 1
  'cell-c2-comp' => [1, 120], # Compute nodes for Cell 2
}

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Virtualbox
  config.vm.box = "trusty64"
  config.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
    config.cache.enable :apt
  else
    puts "[-] WARN: This would be much faster if you ran vagrant plugin install vagrant-cachier first"
  end

  # VMware Fusion
  config.vm.provider "vmware_fusion" do |vmware, override|
    # VMware Fusion / Workstation
    override.vm.box = "trusty64_fusion"
    override.vm.box_url = "https://oss-binaries.phusionpassenger.com/vagrant/boxes/latest/ubuntu-14.04-amd64-vmwarefusion.box"

    # Fusion Performance Hacks
    vmware.vmx["logging"] = "FALSE"
    vmware.vmx["MemTrimRate"] = "0"
    vmware.vmx["MemAllowAutoScaleDown"] = "FALSE"
    vmware.vmx["mainMem.backing"] = "swap"
    vmware.vmx["sched.mem.pshare.enable"] = "FALSE"
    vmware.vmx["snapshot.disabled"] = "TRUE"
    vmware.vmx["isolation.tools.unity.disable"] = "TRUE"
    vmware.vmx["unity.allowCompostingInGuest"] = "FALSE"
    vmware.vmx["unity.enableLaunchMenu"] = "FALSE"
    vmware.vmx["unity.showBadges"] = "FALSE"
    vmware.vmx["unity.showBorders"] = "FALSE"
    vmware.vmx["unity.wasCapable"] = "FALSE"
    vmware.vmx["memsize"] = "2048"
    vmware.vmx["numvcpus"] = "1"
    vmware.vmx["vhv.enable"] = "TRUE"
  end

  nodes.each do |prefix, (count, ip_start)|
    count.times do |i|

      if prefix.include? "comp"
        hostname = "%s-%02d" % [prefix, (i+1)]
      else
        hostname = "%s" % [prefix, (i+1)]
      end

      config.vm.define hostname do |box|
        box.vm.hostname = "#{hostname}"
        box.vm.network :private_network, ip: "172.16.0.#{ip_start+i}", :netmask => "255.255.0.0"
        box.vm.network :private_network, ip: "10.10.0.#{ip_start+i}", :netmask => "255.255.0.0"
        box.vm.network :private_network, ip: "192.168.100.#{ip_start+i}", :netmask => "255.255.255.0"
        box.vm.provision :shell, :path => "#{prefix}.sh"
      end
    end
  end
end