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
