<!--
  Header for the minimal example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Minimal example

One Libre DevOps role, `libre_devops.ssh_bootstrap` from Galaxy, on hosts Terraform can already reach over SSH: it adds SSH keys for the admin account and hardens sshd. Give the hosts and keys in a `.tfvars` file:

```hcl
admin_user      = "azureuser"
authorized_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... ops@example"]
hosts = {
  web01 = { address = "10.0.1.4", user = "azureuser", private_key_file = "~/.ssh/id_ed25519" }
}
```

The end-to-end test (`just e2e`) runs the same kind of call against throwaway SSH containers.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
# Minimal call: one Libre DevOps role from Galaxy on hosts Terraform can already reach over SSH.
# It adds SSH keys for the admin account and hardens sshd, then changes nothing on later applies
# until a role, variable or host changes.
module "this" {
  source = "../../"

  name  = "ssh-bootstrap"
  roles = [{ name = "libre_devops.ssh_bootstrap", version = "1.0.0" }]
  hosts = var.hosts

  vars = {
    ssh_bootstrap_authorized_keys = [
      { user = var.admin_user, keys = var.authorized_keys },
    ]
    ssh_bootstrap_sshd_settings = {
      PermitEmptyPasswords   = false
      PermitRootLogin        = false
      PasswordAuthentication = false
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_ansible"></a> [ansible](#requirement\_ansible) | >= 1.5.0, < 2.0.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.5.0, < 3.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_this"></a> [this](#module\_this) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_user"></a> [admin\_user](#input\_admin\_user) | The existing account on the hosts that gets authorized\_keys. | `string` | `"azureuser"` | no |
| <a name="input_authorized_keys"></a> [authorized\_keys](#input\_authorized\_keys) | Public SSH keys to add for admin\_user. | `list(string)` | n/a | yes |
| <a name="input_hosts"></a> [hosts](#input\_hosts) | Hosts to configure, keyed by inventory name, as the module's hosts input: address, user, port, private\_key\_file and so on. | <pre>map(object({<br/>    address          = optional(string)<br/>    user             = optional(string)<br/>    port             = optional(number)<br/>    private_key_file = optional(string)<br/>    ssh_common_args  = optional(string)<br/>    groups           = optional(list(string), [])<br/>    triggers         = optional(map(string), {})<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_hosts"></a> [hosts](#output\_hosts) | The hosts the role ran on. |
| <a name="output_playbook_path"></a> [playbook\_path](#output\_playbook\_path) | The generated playbook, for running the same thing by hand. |
| <a name="output_run_ids"></a> [run\_ids](#output\_run\_ids) | Map of host name to the ID of its last run. |
<!-- END_TF_DOCS -->
