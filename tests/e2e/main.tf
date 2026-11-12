# End-to-end test configuration, applied by run.sh against throwaway SSH containers.
terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = ">= 1.5.0, < 2.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.0, < 3.0.0"
    }
  }
}

variable "hosts" {
  description = "The test containers, keyed by name, written by run.sh."
  type = map(object({
    address          = string
    port             = number
    user             = string
    private_key_file = string
    family           = string
    machine_id       = string
  }))
}

variable "second_key" {
  description = "A public key the roles add, which run.sh then signs in with."
  type        = string
}

locals {
  hosts = {
    for name, h in var.hosts : name => {
      address          = h.address
      port             = h.port
      user             = h.user
      private_key_file = h.private_key_file
      triggers         = { machine_id = h.machine_id }
    }
  }
}

# Debian family hosts with a usable Python.
module "ssh_bootstrap" {
  source = "../.."

  name  = "e2e-ssh-bootstrap"
  roles = [{ name = "libre_devops.ssh_bootstrap", version = "1.0.0" }]
  hosts = { for name, h in local.hosts : name => h if var.hosts[name].family == "debian" }

  vars = {
    ssh_bootstrap_authorized_keys = [{ user = "ansible", keys = [var.second_key] }]
    ssh_bootstrap_sshd_settings = {
      PermitEmptyPasswords   = false
      PermitRootLogin        = false
      PasswordAuthentication = false
      MaxAuthTries           = 4
    }
  }
}

# RHEL 8 family hosts with only Python 3.6: libre_devops.python first, in the same play.
module "el8" {
  source = "../.."

  name         = "e2e-el8"
  gather_facts = false
  roles = [
    { name = "libre_devops.python", version = "1.0.0" },
    { name = "libre_devops.ssh_bootstrap", version = "1.0.0" },
  ]
  hosts = { for name, h in local.hosts : name => h if var.hosts[name].family == "rhel" }

  vars = {
    ssh_bootstrap_authorized_keys = [{ user = "ansible", keys = [var.second_key] }]
    ssh_bootstrap_sshd_settings   = { MaxAuthTries = 4 }
  }
}

output "ran_on" {
  description = "Every host a module ran on."
  value       = concat(module.ssh_bootstrap.hosts, module.el8.hosts)
}
