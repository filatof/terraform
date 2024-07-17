#создает одну ВМ
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"


#---------загрузка файла состояний в s3-------------
  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket = "test-tfstate-backet"
    region = "ru-central1"
    key    = "terraform1.tfstate"
    shared_credentials_files = [ "storage.key" ] #ссылка на ключ доступа к бакету

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true # Необходимая опция Terraform для версии 1.6.1 и старше.
    skip_s3_checksum            = true # Необходимая опция при описании бэкенда для Terraform версии 1.6.3 и старше.

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

#для статического адреса
#resource "yandex_vpc_address" "addr" {
#  name = "staticAddress"
#  external_ipv4_address {
#    zone_id = "ru-central1-a"
#  }
#}

resource "yandex_compute_disk" "boot-disk" {
  name     = "disk-vm1"
  type     = "network-ssd"
  size     = 10
  image_id = "fd87j6d92jlrbjqbl32q"

  labels = {
    environment = "vm-env-labels"
  }
}

#группы безопасности
resource "yandex_vpc_security_group" "group1" {
  name        = "my-security-group"
  description = "description for my security group"
  network_id  = yandex_vpc_network.test-vpc.id

  labels = {
    my-label = "my-label-value"
  }

  dynamic "ingress" {
    for_each = ["22", "80", "443"]
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
  name        = "test"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 5
  }

  boot_disk {
    disk_id = yandex_compute_disk.boot-disk.id
  }

  network_interface {
    index     = 1
    subnet_id = yandex_vpc_subnet.test-subnet.id
    nat       = true
    #для статического адреса 
    #nat_ip_address = yandex_vpc_address.addr.external_ipv4_address.0.address
  }

  metadata = {
    #ssh-keys = "fill:${file("~/.ssh/id_ed25519.pub")}"
    user-data = "${file("~/metafile.yaml")}"
    hostname = "my-vm"
  }
}

#два варианта вывода ip 
#для статического адреса
#output "external_ip" {
#    value = yandex_vpc_address.addr.external_ipv4_address.0.address
#}

output "external_ip2" {
  value = yandex_compute_instance.vm-test.network_interface.0.nat_ip_address
}
