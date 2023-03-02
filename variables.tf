variable "region" {
  type    = string
  default = "us-east-1"
}

variable "profile" {
  type    = string
  default = "demo"
}

variable "my_vpc" {
    type  = string
  default = "demovpc"
}

variable "cidr_block" {
    type  = string
  default = "10.0.0.0/16"
}
 
variable "public_cidr" {
    type  = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_cidr" {
    type = list(string)
    default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "aws-ami" {
    type = string
}

variable "db_port" {
    type = string
    default = "3306"
}

variable "environment" {
    type = string
    default = "demo"
}