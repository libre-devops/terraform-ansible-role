variable "admin_user" {
  description = "The existing account on the hosts that gets authorized_keys."
  type        = string
  default     = "azureuser"
}

variable "authorized_keys" {
  description = "Public SSH keys to add for admin_user."
  type        = list(string)
}

variable "hosts" {
  description = "Hosts to configure, keyed by inventory name, as the module's hosts input: address, user, port, private_key_file and so on."
  type = map(object({
    address          = optional(string)
    user             = optional(string)
    port             = optional(number)
    private_key_file = optional(string)
    ssh_common_args  = optional(string)
    groups           = optional(list(string), [])
    triggers         = optional(map(string), {})
  }))
}
