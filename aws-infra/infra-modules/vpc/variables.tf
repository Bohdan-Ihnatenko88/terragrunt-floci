variable "env" {
  description = "Enviroment name"
  type = string
  default = "stage"
}

variable "vpc_cidr_block" {
  description = "CIDR"
  type = string
  default = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones for subnets"
  type = list(string)
}

variable "private_subnets" {
  description = "Cidr range for privat subnets"
  type = list(string)
}

variable "public_subnets" {
  description = "Cidr range for public subnets"
  type = list(string)
}

variable "private_subnet_tags" {
  description = "Privat subnets tags"
  type = map(string)
}

variable "public_subnet_tags" {
  description = "Public subnets tags"
  type = map(string)
}
