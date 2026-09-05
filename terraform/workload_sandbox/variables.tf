variable "aws_region" {
  description = "AWS region — musí odpovídat zbytku projektu (GuardDuty scope)"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profil pro Workload account"
  type        = string
  default     = "vl-workload"
}

variable "instance_type" {
  description = "EC2 instance type — t3.micro je free tier eligible"
  type        = string
  default     = "t3.micro"
}

variable "ssh_ingress_cidr" {
  description = "CIDR povolený pro SSH (22). 0.0.0.0/0 = záměrně otevřené, honeypot má lákat provoz z celého internetu."
  type        = string
  default     = "0.0.0.0/0"
}

variable "auto_shutdown_minutes" {
  description = "Za kolik minut od spuštění se instance sama vypne (OS-level shutdown, ne terminate — na skutečné smazání zdrojů použij terraform destroy)"
  type        = number
  default     = 4320 # 3 dny
}

variable "owner_tag" {
  description = "Tag pro identifikaci vlastníka zdroje"
  type        = string
  default     = "vlad-security-sandbox"
}
