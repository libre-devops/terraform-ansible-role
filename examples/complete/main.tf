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
