output "public_ip" {
  value = module.k3s.public_ip
}

output "ssh_command" {
  value = module.k3s.ssh_command
}

output "app_url" {
  value = "http://${module.k3s.public_ip}"
}
