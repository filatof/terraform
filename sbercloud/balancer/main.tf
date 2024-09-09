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

data "sbercloud_availability_zones" "default" {}

data "sbercloud_compute_flavors" "default" {
  availability_zone = "ru-moscow-1a"
  performance_type  = "normal"
  cpu_core_count    = 2
  memory_size       = 4
}

data "sbercloud_images_image" "default" {
  name        = "Ubuntu 22.04 server 64bit"
  os_version = "Ubuntu 22.04 server 64bit"
  most_recent = true
}

resource "sbercloud_vpc" "default" {
  name = "my_vpc"
  cidr = "192.168.1.0/24"
}

resource "sbercloud_vpc_subnet" "default" {
  vpc_id      = sbercloud_vpc.default.id
  cidr   = "192.168.1.0/24"
  name   = "my_subnet"
  gateway_ip = "192.168.1.1"
  ipv6_enable = true
}

resource "sbercloud_network_acl" "default" {
  name = "Acl_default"
  subnets = [
    sbercloud_vpc_subnet.default.id
  ]

  inbound_rules = [
    sbercloud_network_acl_rule.default.id
  ]
}

resource "sbercloud_network_acl_rule" "default" {
  name                   = "Acl_rule"
  protocol               = "tcp"
  action                 = "allow"
  source_ip_address      = sbercloud_vpc.default.cidr
  source_port            = "8080"
  destination_ip_address = "0.0.0.0/0"
  destination_port       = "8081"
}

resource "sbercloud_networking_secgroup" "sg" {
  name                 = "Mysecgr"
  delete_default_rules = true
}

resource "sbercloud_networking_secgroup_rule" "in_v4_tcp_3389" {
  depends_on = [
    sbercloud_compute_eip_associate.default
  ]

  security_group_id = sbercloud_networking_secgroup.sg.id
  ethertype         = "IPv4"
  direction         = "ingress"
  protocol          = "tcp"
  ports             = "3389"
  remote_ip_prefix  = format("%s/32", sbercloud_compute_instance.default.access_ip_v4)
}

resource "sbercloud_networking_secgroup_rule" "in_v4_icmp_all" {
  security_group_id = sbercloud_networking_secgroup.sg.id
  ethertype         = "IPv4"
  direction         = "ingress"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "sbercloud_networking_secgroup_rule" "in_v4_elb_member" {
  security_group_id = sbercloud_networking_secgroup.sg.id
  ethertype         = "IPv4"
  direction         = "ingress"
  protocol          = "tcp"
  ports             = "80,8081"
  remote_ip_prefix  = sbercloud_vpc.default.cidr
}

resource "sbercloud_networking_secgroup_rule" "in_v4_all_group" {
  security_group_id = sbercloud_networking_secgroup.sg.id
  ethertype         = "IPv4"
  direction         = "ingress"
  remote_group_id   = sbercloud_networking_secgroup.sg.id
}

resource "sbercloud_networking_secgroup_rule" "in_v6_all_group" {
  security_group_id = sbercloud_networking_secgroup.sg.id
  ethertype         = "IPv6"
  direction         = "ingress"
  remote_group_id   = sbercloud_networking_secgroup.sg.id
}

resource "sbercloud_networking_secgroup_rule" "out_v4_all" {
  security_group_id = sbercloud_networking_secgroup.sg.id
  ethertype         = "IPv4"
  direction         = "egress"
  remote_ip_prefix  = "0.0.0.0/0"
}

resource "sbercloud_networking_secgroup_rule" "out_v6_all" {
  security_group_id = sbercloud_networking_secgroup.sg.id
  ethertype         = "IPv6"
  direction         = "egress"
  remote_ip_prefix  = "::/0"
}

resource "sbercloud_compute_instance" "default" {
  name              = "instance"
  image_id          = data.sbercloud_images_image.default.id
  flavor_id         = data.sbercloud_compute_flavors.default.ids[0]
  availability_zone = data.sbercloud_availability_zones.default.names[0]
  security_groups   = [sbercloud_networking_secgroup.sg.name]
  user_data          = file("${path.module}/user_data.yaml")
  network {
    uuid = sbercloud_vpc_subnet.default.id
  }
}

resource "sbercloud_vpc_eip" "default" {
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

resource "sbercloud_compute_eip_associate" "default" {
  public_ip   = sbercloud_vpc_eip.default.address
  instance_id = sbercloud_compute_instance.default.id
}

resource "sbercloud_elb_loadbalancer" "default" {
  name            = "elb"
  description     = "Created by terraform"
  vpc_id          = sbercloud_vpc.default.id
  ipv4_subnet_id  = sbercloud_vpc_subnet.default.subnet_id
  ipv6_network_id = sbercloud_vpc_subnet.default.id

  availability_zone = [
    data.sbercloud_availability_zones.default.names[0]
  ]

  tags = {
    owner = "terraform"
  }
}

resource "sbercloud_elb_listener" "default" {
  name            = "elb_listener"
  description     = "Created by terraform"
  protocol        = "HTTP"
  protocol_port   = 8080
  loadbalancer_id = sbercloud_elb_loadbalancer.default.id

  idle_timeout     = 60
  request_timeout  = 60
  response_timeout = 60

  tags = {
    owner = "terraform"
  }
}

resource "sbercloud_elb_pool" "default" {
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = sbercloud_elb_listener.default.id

  persistence {
    type = "HTTP_COOKIE"
  }
}

resource "sbercloud_elb_monitor" "default" {
  protocol    = "HTTP"
  interval    = 20
  timeout     = 15
  max_retries = 10
  url_path    = "/"
  port        = 8080
  pool_id     = sbercloud_elb_pool.default.id
}

resource "sbercloud_elb_member" "default" {
  address       = sbercloud_compute_instance.default.access_ip_v4
  protocol_port = 8080
  pool_id       = sbercloud_elb_pool.default.id
  subnet_id     = sbercloud_vpc_subnet.default.subnet_id
}


output "loadbalancer_ip" {
  value = sbercloud_vpc_eip.default.address
}
