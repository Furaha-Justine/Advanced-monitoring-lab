output "instance_public_ip" {
  value = module.ec2.public_ip
}

output "instance_public_dns" {
  value = module.ec2.public_dns
}

output "ssh_user" {
  value = var.ssh_user
}

output "key_name" {
  value = module.keypair.key_name
}

output "private_key_path" {
  value = module.keypair.private_key_path
}

output "app_url" {
  value = "http://${module.ec2.public_ip}:${var.app_port}"
}

output "ssh_connect_command" {
  value = "ssh -i ${module.keypair.private_key_path} ${var.ssh_user}@${module.ec2.public_ip}"
}