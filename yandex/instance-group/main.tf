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
    bucket                   = "test-tfstate-backet"
    region                   = "ru-central1"
    key                      = "instance-group.tfstate"
    shared_credentials_files = ["storage.key"] #ссылка на ключ доступа к бакету

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

#-------------определяем  сеть 
resource "yandex_vpc_network" "web-net" {
  name = "EQ-network"
}

#-----------оперделяем подсети в разных зонах 
resource "yandex_vpc_subnet" "subnet-a" {
  v4_cidr_blocks = ["10.2.0.0/16"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.web-net.id
}

resource "yandex_vpc_subnet" "subnet-b" {
  v4_cidr_blocks = ["10.1.0.0/16"]
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.web-net.id
}

#-------------определяем группу серверов
resource "yandex_compute_instance_group" "web-group" {
  name                = "test-ig"
  service_account_id  = "aje2n0stcln3l580lk76"
  deletion_protection = false
  instance_template {
    platform_id = "standard-v1"
    name         = "instance-{instance.index}" # Присваиваем уникальное имя каждому инстансу в группе
    resources {
      memory        = 1
      cores         = 2
      core_fraction = 5
    }
    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = "fd87j6d92jlrbjqbl32q"
      }
    }
    network_interface {
      network_id = yandex_vpc_network.web-net.id
      subnet_ids = ["${yandex_vpc_subnet.subnet-a.id}", "${yandex_vpc_subnet.subnet-b.id}"]
      nat        = true
    }

    metadata = {
      user-data = "${file("~/metafile.yaml")}"
      #ssh-keys = "fill:${file("~/.ssh/id_ed25519.pub")}"
      user-data = "${file("user_data.sh")}"

    }
    network_settings {
      type = "STANDARD"
    }
  }

  scale_policy {
    fixed_scale {
      size = 2
    }
  }

  allocation_policy {
    zones = ["ru-central1-a", "ru-central1-b"]
  }

  deploy_policy {
    max_unavailable = 1
    max_creating    = 1
    max_expansion   = 0
    max_deleting    = 1
  }

  load_balancer {
    target_group_name = "web-target-group"
  }
}

resource "yandex_lb_network_load_balancer" "web" {
  name = "my-network-load-balancer"

  listener {
    name = "web-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.web-group.load_balancer[0].target_group_id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
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

resource "yandex_dns_recordset" "web" {
  zone_id = yandex_dns_zone.example_zone.id
  name    = "www.nanocorpinfra.ru."
  type    = "A"
  ttl     = 300
  
  data =  [for listener in yandex_lb_network_load_balancer.web.listener : [for addr in listener.external_address_spec : addr.address if listener.name == "web-listener"][0]]
}

output "web_loadbalancer_url" {
  value = [for listener in yandex_lb_network_load_balancer.web.listener : [for addr in listener.external_address_spec : addr.address if listener.name == "web-listener"][0]][0]
}