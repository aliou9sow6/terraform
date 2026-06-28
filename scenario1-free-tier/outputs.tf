###############################################################
# outputs.tf — Valeurs exportées après terraform apply
# Scénario 1 : Free Tier
###############################################################

output "vpc_id" {
  description = "ID du VPC créé"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID du subnet public"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID du Security Group"
  value       = aws_security_group.app.id
}

output "instance_id" {
  description = "ID de l'instance EC2"
  value       = aws_instance.app.id
}

output "instance_private_ip" {
  description = "IP privée de l'instance EC2"
  value       = aws_instance.app.private_ip
}

output "elastic_ip" {
  description = "Elastic IP publique de l'instance"
  value       = aws_eip.app.public_ip
}

output "frontend_url" {
  description = "URL d'accès au frontend React"
  value       = "http://${aws_eip.app.public_ip}"
}

output "backend_url" {
  description = "URL d'accès à l'API backend"
  value       = "http://${aws_eip.app.public_ip}:${var.app_port_backend}"
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à l'instance"
  value       = "ssh -i portfolio-keypair.pem ubuntu@${aws_eip.app.public_ip}"
}

output "key_pair_name" {
  description = "Nom de la paire de clés AWS"
  value       = aws_key_pair.portfolio.key_name
}

output "private_key_path" {
  description = "Chemin local de la clé privée SSH"
  value       = local_file.private_key.filename
  sensitive   = true
}
