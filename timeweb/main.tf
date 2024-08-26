terraform {
  required_providers {
    twc = {
      source = "tf.timeweb.cloud/timeweb-cloud/timeweb-cloud"
    }
  }
  required_version = ">= 0.13"
}

data "twc_configurator" "configurator" {
  location  = "nl-1"
  disk_type = "nvme"
}

data "twc_os" "os" {
  name    = "ubuntu"
  version = "22.04"
}

data "twc_ssh_keys" "my_ssh_key" {
  name = "fill@MacBookAir.local"
}

resource "twc_server" "openvpn-server" {
  name = "Openvpn-server"
  os_id = data.twc_os.os.id
  availability_zone = "ams-1"

  configuration {
    configurator_id = data.twc_configurator.configurator.id
    disk = 1024 * 40
    cpu = 1
    ram = 2048
  }
 ssh_keys_ids = [data.twc_ssh_keys.my_ssh_key.id]
}


resource "twc_floating_ip" "openvpn-floating-ip" {
  availability_zone = "ams-1"
  comment = "Some floating IP"
  resource {
    type = "server"
    id   = twc_server.openvpn-server.id
  }
}

output "public_ip" {
  value = twc_floating_ip.openvpn-floating-ip.ip
  description = "The public IP address of the server."
}
