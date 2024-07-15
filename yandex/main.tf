terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = ""
  cloud_id  = "b1givfjnecaq6gsd91ml"
  folder_id = "b1g7qh7t0i4sftogmaue"
  zone      = "ru-central1-d"
}

data "yandex_compute_image" "my-ubuntu-2004-1" {
  family = "ubuntu-2004-lts"
}

resource "yandex_compute_instance" "my-vm-1" {
  name        = "test-vm-1"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.my-ubuntu-2004-1.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.my-sn-2.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
  }
}

resource "yandex_vpc_network" "my-nw-2" {
  name = "my-nw-2"
}

resource "yandex_vpc_subnet" "my-sn-2" {
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.my-nw-2.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

output "internal_ip_address_vm_1" {
  value = yandex_compute_instance.my-vm-1.network_interface.0.ip_address
}

output "external_ip_address_vm_1" {
  value = yandex_compute_instance.my-vm-1.network_interface.0.nat_ip_address
}

