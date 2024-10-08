terraform {
  #сохраним файл состояния в бакете
  backend "s3" {
    bucket   = "terraformbucket"
    key      = "terraform.tfstate"
    region   = "ru-moscow-1"
    endpoint = "https://obs.ru-moscow-1.hc.sbercloud.ru"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true # Необходимая опция Terraform для версии 1.6.1 и старше.
    skip_s3_checksum            = true # Необходимая опция при описании бэкенда для Terraform версии 1.6.3 и старше.
  }
  required_providers {
    sbercloud = {
      source = "sbercloud-terraform/sbercloud"
    }
  }
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
  ports                   = "22,80,443"
  protocol                = "tcp"
  priority                = 5
  remote_ip_prefix  = "0.0.0.0/0"  # Разрешить со всех IP-адресов
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
######################################################
resource "sbercloud_compute_instance" "instance" {
  name              = "instance_${count.index}"
  image_id          = data.sbercloud_images_image.ubuntu.id
  flavor_id         = data.sbercloud_compute_flavors.minimal.ids[0]
  availability_zone  = "ru-moscow-1a"
  key_pair           = sbercloud_compute_keypair.keypair.name
  security_group_ids = [sbercloud_networking_secgroup.secgroup.id]

  user_data          = file("${path.module}/user_data.yaml")

  network {
    uuid = sbercloud_vpc_subnet.my_subnet.id
  }
  count = 2
}

resource "sbercloud_vpc_eip" "eip_1" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name        = "test"
    size        = 5
    share_type  = "PER"
    charge_mode = "traffic"
  }
}

resource "sbercloud_lb_loadbalancer" "elb_1" {
  name          = "my_elb_1"
  vip_subnet_id = sbercloud_vpc_subnet.my_subnet.subnet_id
  vip_address =  sbercloud_vpc_eip.eip_1.address
}

resource "sbercloud_lb_listener" "listener_1" {
  name            = "listener_http"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = sbercloud_lb_loadbalancer.elb_1.id
}

resource "sbercloud_lb_pool" "group_1" {
  name        = "group_1"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = sbercloud_lb_listener.listener_1.id
}

resource "sbercloud_lb_monitor" "health_check" {
  name           = "health_check"
  type           = "HTTP"
  url_path       = "/"
  expected_codes = "200-202"
  delay          = 10
  timeout        = 5
  max_retries    = 3
  pool_id        = sbercloud_lb_pool.group_1.id
}

resource "sbercloud_lb_member" "member_1" {
  address       = sbercloud_compute_instance.instance[0].access_ip_v4
  protocol_port = 80
  weight        = 1
  pool_id       = sbercloud_lb_pool.group_1.id
  subnet_id     = sbercloud_vpc_subnet.my_subnet.subnet_id
}

resource "sbercloud_lb_member" "member_2" {
  address       = sbercloud_compute_instance.instance[1].access_ip_v4
  protocol_port = 80
  weight        = 1
  pool_id       = sbercloud_lb_pool.group_1.id
  subnet_id     = sbercloud_vpc_subnet.my_subnet.subnet_id
}
#####################################################
output "loadbalancer_ip" {
  value = sbercloud_vpc_eip.eip_1.address
}

output "instance_ips" {
  value = [for instance in sbercloud_compute_instance.instance : instance.access_ip_v4]
}

