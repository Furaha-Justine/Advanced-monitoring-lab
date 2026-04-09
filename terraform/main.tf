terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
  backend "s3" {
  bucket         = "docker-app-tfstate-445567114084"
  key            = "docker-app/terraform.tfstate"
  region         = "eu-west-1"
  dynamodb_table = "docker-app-tfstate-lock"
  encrypt        = true
}
}

provider "aws" {
  region = var.aws_region
}

module "keypair" {
  source   = "./modules/keypair"
  key_name = var.key_name
}

module "security_group" {
  source       = "./modules/security_group"
  project_name = var.project_name
  app_port     = var.app_port
}

module "ec2" {
  source            = "./modules/ec2"
  project_name      = var.project_name
  instance_type     = var.instance_type
  key_name          = module.keypair.key_name
  security_group_id = module.security_group.security_group_id
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tftpl", {
    public_ip = module.ec2.public_ip
    ssh_user  = var.ssh_user
    key_path  = module.keypair.private_key_path
  })
  filename = "${path.module}/../ansible/inventory.ini"
}