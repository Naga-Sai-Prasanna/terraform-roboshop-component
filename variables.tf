variable "project" {
  type    = string
  default = "roboshop"

}

variable "environment" {
  type    = string
  default = "dev"
}

variable "domain_name" {
   default = "prasanna.fun"
}

variable "component" {
  type = string
}


variable "rule_priority" {

  }
  
variable "app_version" {
 
   default = "v3"
   type = string
}