terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"

  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket = "test-tfstate-backet"
    region = "ru-central1"
    key    = "terraform1.tfstate"
    shared_credentials_files = [ "storage.key" ]

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

provider "yandex" {
  service_account_key_file = "key.json"
  cloud_id                 = "b1givfjnecaq6gsd91ml"
  folder_id                = "b1g7qh7t0i4sftogmaue"
  zone                     = "ru-central1-a"
}

resource "yandex_vpc_network" "test-vpc" {
  name = "EQ-test"
}

resource "yandex_vpc_subnet" "test-subnet" {
  v4_cidr_blocks = ["10.2.0.0/16"]
  network_id     = yandex_vpc_network.test-vpc.id
}

resource "yandex_compute_disk" "boot-disk" {
  count    = 3
  name     = "disk-vm${count.index + 1}"
  type     = "network-ssd"
  size     = 10
  image_id = "fd87j6d92jlrbjqbl32q"

  labels = {
    environment = "vm-env-labels"
  }
}

resource "yandex_vpc_security_group" "group1" {
  name        = "my-security-group"
  description = "description for my security group"
  network_id  = yandex_vpc_network.test-vpc.id

  labels = {
    my-label = "my-label-value"
  }

  dynamic "ingress" {
    for_each = ["22", "80", "443", "3000", "3100", "9090", "9080", "9093", "9095", "9100", "9113", "9104" ]
    content {
      protocol       = "TCP"
      description    = "rule1 description"
      v4_cidr_blocks = ["0.0.0.0/0"]
      from_port      = ingress.value
      to_port        = ingress.value
    }
  }

  egress {
    protocol       = "ANY"
    description    = "rule2 description"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_compute_instance" "vm-test" {
  count       = 3
  name        = "test-${count.index + 1}"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 5
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk[count.index].id
  }

  network_interface {
    index     = 1
    subnet_id = yandex_vpc_subnet.test-subnet.id
    nat       = true
  }

  metadata = {
    user-data = "${file("~/metafile.yaml")}"
    hostname = "my-vm-${count.index + 1}"
  }
}

resource "yandex_dns_zone" "example_zone" {
  name        = "nanocorpinfra"
  description = "my zone dns"

  labels = {
    label1 = "lable_zone_dns"
  }

  zone    = "nanocorpinfra.ru."
  public  = true
}

resource "yandex_dns_recordset" "vm-test" {
  zone_id = yandex_dns_zone.example_zone.id
  name    = "www.nanocorpinfra.ru."
  type    = "A"
  ttl     = 300
  
  data = [yandex_compute_instance.vm-test[0].network_interface[0].nat_ip_address]
}

output "external_ips" {
  value = [for instance in yandex_compute_instance.vm-test : instance.network_interface.0.nat_ip_address]
}