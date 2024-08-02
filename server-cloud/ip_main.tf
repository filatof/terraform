terraform {
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

variable "access_key" {}
variable "secret_key" {}
variable "ssh_key_name" {}
variable "ssh_public_key" {}

resource "sbercloud_vpc" "my_vpc" {
  name = "my_vpc"
  cidr = "192.168.1.0/24"
}

resource "sbercloud_vpc_subnet" "my_subnet" {
  vpc_id = sbercloud_vpc.my_vpc.id
  cidr   = "192.168.1.0/24"
  name   = "my_subnet"
}

resource "sbercloud_networking_secgroup" "secgroup" {
  name = "default"
  description = "Default security group"
}

resource "sbercloud_networking_secgroup_rule" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = sbercloud_networking_secgroup.secgroup.id
}

resource "sbercloud_compute_keypair" "keypair" {
  name      = var.ssh_key_name
  public_key = var.ssh_public_key
}

data "sbercloud_images_image" "ubuntu" {
  name        = "Ubuntu 18.04 server 64bit"
  most_recent = true
}

data "sbercloud_compute_flavors" "minimal" {
  availability_zone = "ru-moscow-1a"
  performance_type  = "normal"
  cpu_core_count    = 1
  memory_size       = 1
}

resource "sbercloud_eip" "my_eip" {
  bandwidth_size = 5
}

resource "sbercloud_compute_instance" "basic" {
  name               = "ubuntu-instance"
  image_id           = data.sbercloud_images_image.ubuntu.id
  flavor_id          = data.sbercloud_compute_flavors.minimal.ids[0]
  key_name           = sbercloud_compute_keypair.keypair.name
  security_group_ids = [sbercloud_networking_secgroup.secgroup.id]
  availability_zone  = "ru-moscow-1a"

  network {
    uuid = sbercloud_vpc_subnet.my_subnet.id
  }

  eip {
    eip_id = sbercloud_eip.my_eip.id
  }
}

output "instance_ip" {
  value = sbercloud_eip.my_eip.public_ip
}
