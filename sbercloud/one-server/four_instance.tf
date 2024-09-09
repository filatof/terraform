#Создает четыре инстанса. Один с публичным ip
#Настраивает nat. Все ходят через него в инет

terraform {
  backend "s3" {
    bucket   = "terraformbucket"
    key      = "terraform.tfstate"
    region   = "ru-moscow-1"
    endpoint = "https://obs.ru-moscow-1.hc.sbercloud.ru"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
  required_providers {
    sbercloud = {
      source = "sbercloud-terraform/sbercloud"
    }
    yandex = {
      source  = "yandex-cloud/yandex"
    }
  }
}

provider "yandex" {
  service_account_key_file = "key.json"
  cloud_id                 = "b1givfjnecaq6gsd91ml"
  folder_id                = "b1g7qh7t0i4sftogmaue"
  zone                     = "ru-central1-a"
}

provider "sbercloud" {
  auth_url   = "https://iam.ru-moscow-1.hc.sbercloud.ru/v3"
  region     = "ru-moscow-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "sbercloud_vpc" "my_vpc" {
  name = "my_vpc"
  cidr = "192.168.1.0/24"
}

resource "sbercloud_vpc_subnet" "my_subnet" {
  vpc_id = sbercloud_vpc.my_vpc.id
  cidr   = "192.168.1.0/24"
  name   = "my_subnet"
  gateway_ip = "192.168.1.1"
}

resource "sbercloud_networking_secgroup" "secgroup" {
  name = "my-test"
  description = "Default security group"
}

resource "sbercloud_networking_secgroup_rule" "ssh" {
  direction         = "ingress"
  security_group_id = sbercloud_networking_secgroup.secgroup.id
  action                  = "allow"
  ethertype               = "IPv4"
  ports                   = "22,80,443,3000,3100,9080,9090,9095,9100,9113"
  protocol                = "tcp"
  priority                = 5
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "sbercloud_compute_keypair" "keypair" {
  name      = var.ssh_key_name
  public_key = var.ssh_public_key
}

data "sbercloud_images_image" "ubuntu" {
  name        = "Ubuntu 22.04 server 64bit"
  os_version = "Ubuntu 22.04 server 64bit"
  most_recent = true
}

data "sbercloud_compute_flavors" "minimal" {
  availability_zone = "ru-moscow-1a"
  performance_type  = "normal"
  cpu_core_count    = 1
  memory_size       = 1
}

resource "sbercloud_vpc_eip" "my_eip" {
  count = 1
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name        = "bandwidth_1"
    size        = 8
    share_type  = "PER"
    charge_mode = "traffic"
  }
}

resource "sbercloud_compute_eip_associate" "associated" {
  count      = 1
  public_ip  = sbercloud_vpc_eip.my_eip[count.index].address
  instance_id = sbercloud_compute_instance.nat_instance[count.index].id
}

resource "sbercloud_compute_instance" "nat_instance" {
  count              = 1
  name               = "nat-instance"
  image_id           = data.sbercloud_images_image.ubuntu.id
  flavor_id          = data.sbercloud_compute_flavors.minimal.ids[0]
  key_pair           = sbercloud_compute_keypair.keypair.name
  security_group_ids = [sbercloud_networking_secgroup.secgroup.id]
  availability_zone  = "ru-moscow-1a"
  user_data          = file("${path.module}/user_ng_proxy.sh")

  network {
    uuid = sbercloud_vpc_subnet.my_subnet.id
    fixed_ip_v4 = "192.168.1.101"
  }
}

resource "sbercloud_compute_instance" "basic" {
  count              = 3
  name               = "ubuntu-instance-${count.index + 1}"
  image_id           = data.sbercloud_images_image.ubuntu.id
  flavor_id          = data.sbercloud_compute_flavors.minimal.ids[0]
  key_pair           = sbercloud_compute_keypair.keypair.id
  security_group_ids = [sbercloud_networking_secgroup.secgroup.id]
  availability_zone  = "ru-moscow-1a"
  user_data          = file("${path.module}/user_data.sh")

  network {
    uuid = sbercloud_vpc_subnet.my_subnet.id
    fixed_ip_v4 = "192.168.1.${count.index + 102}"
  }
}

resource "sbercloud_vpc_route" "nat_route" {
  vpc_id      = sbercloud_vpc.my_vpc.id
  destination = "0.0.0.0/0"
  type        = "ecs"  # Если nexthop это ECS
  nexthop     = sbercloud_compute_instance.nat_instance[0].id  
}

output "instance_ips" {
  value = [for eip in sbercloud_vpc_eip.my_eip : eip.address]
}

output "private_ips" {
  value = concat(
    [for instance in sbercloud_compute_instance.nat_instance : instance.network[0].fixed_ip_v4],
    [for instance in sbercloud_compute_instance.basic : instance.network[0].fixed_ip_v4]
  )
}

resource "yandex_dns_zone" "example_zone" {
  name        = "infra"
  description = "my zone dns"
  labels = {
    label1 = "lable_zone_dns"
  }
  zone    = "infrastruct.ru."
  public  = true
}

resource "yandex_dns_recordset" "web" {
  zone_id = yandex_dns_zone.example_zone.id
  name    = "infrastruct.ru."
  type    = "A"
  ttl     = 300
  data =  [ sbercloud_vpc_eip.my_eip[0].address ]
}


resource "yandex_dns_recordset" "www" {
  zone_id = yandex_dns_zone.example_zone.id
  name    = "www.infrastruct.ru."
  type    = "A"
  ttl     = 300
  data =  [ sbercloud_vpc_eip.my_eip[0].address ]
}

resource "yandex_dns_recordset" "monitor" {
  zone_id = yandex_dns_zone.example_zone.id
  name    = "monitor.infrastruct.ru."
  type    = "A"
  ttl     = 300
  data =  [ sbercloud_vpc_eip.my_eip[0].address ]
}

resource "yandex_dns_recordset" "grafana" {
  zone_id = yandex_dns_zone.example_zone.id
  name    = "grafana.infrastruct.ru."
  type    = "A"
  ttl     = 300
  data =  [ sbercloud_vpc_eip.my_eip[0].address ]
}

resource "yandex_dns_recordset" "ca" {
  zone_id = yandex_dns_zone.example_zone.id
  name    = "ca.infrastruct.ru."
  type    = "A"
  ttl     = 300
  data =  [ sbercloud_vpc_eip.my_eip[0].address ]
}
