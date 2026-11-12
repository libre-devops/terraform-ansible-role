<!--
  Header for the complete example README. Edit this file, then run `just docs`
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

# Complete example

Defender for Endpoint and then Azure Arc on RHEL 8 family hosts that only have Python 3.6. Each call runs `libre_devops.python` first in the same play, the onboarding package and the Arc service principal secret go in `sensitive_vars`, and each server gets its own Arc resource name and tags through `host_vars`. The two calls have separate lifecycles: changing an Arc setting re-runs only the Arc roles.

Give the hosts, the Defender organisation ID and the Arc target in a `.tfvars` file, and the two secrets from your secret store (for example `TF_VAR_mde_onboarding_json` and `TF_VAR_arc_service_principal_secret` in CI).

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
# Two calls, each with its own lifecycle: changing the Arc settings re-runs only the Arc roles.
# Both target RHEL 8 family hosts that only have Python 3.6, which ansible-core 2.17 and later
# cannot use, so each call runs libre_devops.python first, in the same play, with fact gathering
# off until it has given the host a Python Ansible can use. It is quick when there is nothing to do.

# Microsoft Defender for Endpoint: installed from Microsoft's repository, onboarded with the
# package from the Defender portal (checked against your organisation first), and a managed
# configuration profile.
module "mde" {
  source = "../../"

  name         = "mde-linux"
  gather_facts = false
  roles = [
    { name = "libre_devops.python", version = "1.0.0" },
    { name = "libre_devops.mde_linux", version = "1.1.0" },
  ]
  hosts = var.hosts

  vars = {
    mde_linux_expected_org_id         = var.mde_org_id
    mde_linux_check_onboarding_org_id = true
    mde_linux_managed_config = {
      antivirusEngine = {
        enforcementLevel = "real_time"
        threatTypeSettings = [
          { key = "potentially_unwanted_application", value = "block" },
          { key = "archive_bomb", value = "audit" },
        ]
      }
      cloudService = {
        enabled                          = true
        automaticDefinitionUpdateEnabled = true
        automaticSampleSubmissionConsent = "safe"
      }
    }
  }

  # The onboarding package is a secret: kept out of plan output and written to a file only the
  # current user can read.
  sensitive_vars = {
    mde_linux_onboarding_content = var.mde_onboarding_json
  }
}

# Azure Arc, after Defender: every server in the same subscription and resource group, each with
# its own resource name and tags from host_vars.
module "arc" {
  source = "../../"

  name         = "azure-arc"
  gather_facts = false
  roles = [
    { name = "libre_devops.python", version = "1.0.0" },
    { name = "libre_devops.azure_arc", version = "1.0.0" },
  ]
  hosts = var.hosts

  vars = {
    azure_arc_tenant_id            = var.arc_tenant_id
    azure_arc_subscription_id      = var.arc_subscription_id
    azure_arc_resource_group       = var.arc_resource_group
    azure_arc_location             = var.arc_location
    azure_arc_service_principal_id = var.arc_service_principal_id
  }

  sensitive_vars = {
    azure_arc_service_principal_secret = var.arc_service_principal_secret
  }

  host_vars = {
    for name, target in var.arc_targets : name => {
      azure_arc_resource_name = target.resource_name
      azure_arc_tags          = target.tags
    }
  }

  depends_on = [module.mde]
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
| <a name="module_arc"></a> [arc](#module\_arc) | ../../ | n/a |
| <a name="module_mde"></a> [mde](#module\_mde) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_arc_location"></a> [arc\_location](#input\_arc\_location) | Azure region for the Arc-enabled server resources. | `string` | `"uksouth"` | no |
| <a name="input_arc_resource_group"></a> [arc\_resource\_group](#input\_arc\_resource\_group) | Resource group for the Arc-enabled server resources. | `string` | n/a | yes |
| <a name="input_arc_service_principal_id"></a> [arc\_service\_principal\_id](#input\_arc\_service\_principal\_id) | Application (client) ID of the service principal that onboards the servers to Azure Arc. | `string` | n/a | yes |
| <a name="input_arc_service_principal_secret"></a> [arc\_service\_principal\_secret](#input\_arc\_service\_principal\_secret) | Secret of the Arc onboarding service principal. | `string` | n/a | yes |
| <a name="input_arc_subscription_id"></a> [arc\_subscription\_id](#input\_arc\_subscription\_id) | Subscription for the Arc-enabled server resources. | `string` | n/a | yes |
| <a name="input_arc_targets"></a> [arc\_targets](#input\_arc\_targets) | Per-host Azure Arc settings, keyed by the names in hosts: the resource name in Azure and its tags. | <pre>map(object({<br/>    resource_name = string<br/>    tags          = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_arc_tenant_id"></a> [arc\_tenant\_id](#input\_arc\_tenant\_id) | Entra ID tenant for Azure Arc. | `string` | n/a | yes |
| <a name="input_hosts"></a> [hosts](#input\_hosts) | Hosts to configure, keyed by inventory name, as the module's hosts input. For VMs built in<br/>the same configuration, take address from the VM and put its ID in triggers, so a replaced VM<br/>is configured again with a fresh host key. To reach private VMs through a jump host or Azure<br/>Bastion tunnel, set ssh\_common\_args, for example "-o ProxyJump=jump.example.com". | <pre>map(object({<br/>    address          = optional(string)<br/>    user             = optional(string)<br/>    port             = optional(number)<br/>    private_key_file = optional(string)<br/>    ssh_common_args  = optional(string)<br/>    groups           = optional(list(string), [])<br/>    triggers         = optional(map(string), {})<br/>  }))</pre> | n/a | yes |
| <a name="input_mde_onboarding_json"></a> [mde\_onboarding\_json](#input\_mde\_onboarding\_json) | The content of mdatp\_onboard.json from the Defender portal (Linux Server, Your preferred Linux configuration management tool). | `string` | n/a | yes |
| <a name="input_mde_org_id"></a> [mde\_org\_id](#input\_mde\_org\_id) | Your Defender for Endpoint organisation ID. The role refuses an onboarding package for any other organisation. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arc_hosts"></a> [arc\_hosts](#output\_arc\_hosts) | The hosts Azure Arc was set up on. |
| <a name="output_arc_run_ids"></a> [arc\_run\_ids](#output\_arc\_run\_ids) | Map of host name to the ID of its last Azure Arc run. |
| <a name="output_mde_hosts"></a> [mde\_hosts](#output\_mde\_hosts) | The hosts Defender for Endpoint was set up on. |
| <a name="output_mde_run_ids"></a> [mde\_run\_ids](#output\_mde\_run\_ids) | Map of host name to the ID of its last Defender for Endpoint run. |
<!-- END_TF_DOCS -->
