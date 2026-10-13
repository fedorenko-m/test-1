variable "region" {
    description = "AWS region"
    type        = string
    default     = "eu-central-1"
}

variable "instance_type" {
    description = "EC2 instance type for the test server"
    type        = string
    default     = "t3.micro"
}

variable "deploy_public_key" {
    description = "Public SSH key used by CI/CD (the private part goes to the DEPLOY_SSH_KEY secret)"
    type        = string
}

variable "ssh_allowed_cidr" {
    description = "CIDR allowed to connect over SSH"
    type        = string
    default     = "0.0.0.0/0"
}
