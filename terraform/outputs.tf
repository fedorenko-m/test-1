output "public_ip" {
    description = "Server IP: use it as DEPLOY_HOST and open it in the browser"
    value       = aws_instance.web.public_ip
}
