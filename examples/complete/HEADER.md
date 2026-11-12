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
