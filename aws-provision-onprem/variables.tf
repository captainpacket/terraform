variable "apphost" {
  description = "Name or IP address of the Forward Enterprise instance"
  type        = string
}

variable "setupid" {
  description = "Name of the setup ID for collection"
  type        = string
}

variable "networkid" {
  description = "Forward Networks Network ID (look in the address bar for networkId=)"
  type        = string
}

variable "regions" {
  description = "List of AWS regions"
  type        = list(string)
}

variable "fwduser" {
  description = "Forward Networks API username"
  type        = string
}

variable "fwdpassword" {
  description = "Forward Networks API password"
  type        = string
}
