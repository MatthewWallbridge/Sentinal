Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"

config.vm.define "db" do |db|
    db.vm.hostname = "db"
    db.vm.network "private_network", ip: "192.168.56.11"
    db.vm.provision "shell", path: "provisioning/db.sh"
  end

config.vm.define "backend" do |backend|
    backend.vm.hostname = "backend"
    backend.vm.network "private_network", ip: "192.168.56.12"
    backend.vm.network "forwarded_port", guest: 5000, host: 5000
    backend.vm.provision "shell", path: "provisioning/backend.sh"
  end

config.vm.define "frontend" do |frontend|
    frontend.vm.hostname = "frontend"
    frontend.vm.network "private_network", ip: "192.168.56.13"
    frontend.vm.network "forwarded_port", guest: 3000, host: 3000
    frontend.vm.provision "shell", path: "provisioning/frontend.sh"
  end
end