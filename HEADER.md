<!--
  Hand-written part of the README. Edit this file, then run `just docs` (or terraform-docs .) to
  regenerate the reference section between the markers.
-->
<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Ansible Role

Run Ansible roles on hosts from Terraform: name the roles, the hosts and the variables, and the module installs the roles from Galaxy, writes the playbook and runs it, again only when something changed.

[![CI](https://github.com/libre-devops/terraform-ansible-role/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-ansible-role/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-ansible-role?sort=semver&label=release)](https://github.com/libre-devops/terraform-ansible-role/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-ansible-role)](./LICENSE)

---

Built for the [Libre DevOps Ansible roles](https://github.com/orgs/libre-devops/repositories?q=ansible-role), such as `libre_devops.mde_linux`, `libre_devops.azure_arc` and `libre_devops.python`, and works with any role `ansible-galaxy` can install. It uses the [`ansible/ansible`](https://registry.terraform.io/providers/ansible/ansible/latest) provider.

## Usage

```hcl
module "ssh_bootstrap" {
  source  = "libre-devops/role/ansible"
  version = "~> 4.0"

  name  = "ssh-bootstrap"
  roles = [{ name = "libre_devops.ssh_bootstrap", version = "1.0.0" }]

  hosts = {
    web01 = { address = "10.0.1.4", user = "azureuser", private_key_file = "~/.ssh/id_ed25519" }
    web02 = { address = "10.0.1.5", user = "azureuser", private_key_file = "~/.ssh/id_ed25519" }
  }

  vars = {
    ssh_bootstrap_authorized_keys = [
      { user = "azureuser", keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... ops@example"] },
    ]
    ssh_bootstrap_sshd_settings = {
      PermitRootLogin        = false
      PasswordAuthentication = false
    }
  }
}
```

`vars` takes the role's variables exactly as its README documents them, written in HCL: strings, numbers, booleans, lists and maps all arrive as those types. There is no playbook, inventory or `requirements.yml` to write.

## Contents

- [Requirements](#requirements-on-the-machine-running-terraform)
- [How it works](#how-it-works)
- [When the roles run](#when-the-roles-run)
- [Recipes](#recipes)
- [Troubleshooting](#troubleshooting)
- [Limitations](#limitations)
- [Examples](#examples)
- [Developing](#developing)
- [Security scan exceptions](#security-scan-exceptions)
- [Reference](#reference)

## Requirements on the machine running Terraform

The roles run from wherever Terraform runs: your workstation, a CI runner or a pipeline agent.

| Need | Why |
|---|---|
| Terraform 1.9 or later | Cross-variable validation. |
| ansible-core, with `ansible-playbook` and `ansible-galaxy` on `PATH` | The provider runs `ansible-playbook`, and the module installs roles with `ansible-galaxy`. Set `ansible_playbook_binary` and `ansible_galaxy_binary` to use others, such as ones in a virtual environment. |
| Linux or macOS with bash and ssh | The module generates a bash script, and Ansible reaches Linux hosts over SSH. `flock` (part of util-linux, on every Linux runner) is used when present. |
| Access to Galaxy, or to wherever `src` points | Roles and their collections are installed at the first run, and again on a fresh checkout. |

ansible-core decides which Python versions the hosts need: ansible-core 2.17 and later cannot use Python 3.6, which is all RHEL 8 and SLES 15 have. Put [`libre_devops.python`](https://github.com/libre-devops/ansible-role-python) first, as in [RHEL 8 hosts](#rhel-8-hosts-with-only-python-36).

## How it works

Each module call gets its own working directory, `.terraform/ansible/<name>` in the root module (so Git already ignores it):

| File | What it is |
|---|---|
| `requirements.yml` | The roles from `roles`, and any `collections`. |
| `playbook.yml` | A play that waits for each host's SSH port, then a play that runs the roles in order. |
| `group_vars/all.json` | `vars` and `sensitive_vars`. |
| `host_vars/<host>.json` | How to reach the host (from `hosts`), plus its `host_vars`. |
| `run.sh` | What the provider calls instead of `ansible-playbook`. It installs the roles, and the collections each role's own `requirements.yml` lists, when they are missing or `requirements.yml` changed, then runs `ansible-playbook`. |
| `roles/`, `collections/` | Installed by `run.sh`. Ansible finds both next to the playbook, so nothing is installed globally. |
| `known_hosts/` | Host keys accepted for each host (see `ssh_host_key_checking`). |

The roles run once per host, through one `ansible_playbook` resource each, so Terraform runs hosts in parallel and a host added later is configured on its own.

Variables are written to `group_vars` and `host_vars`, not passed as extra vars. Extra vars outrank everything in Ansible, so a role could not change them with `set_fact` (which `libre_devops.python` needs, to set the interpreter), and they would also apply to the control node when a task is delegated to it. Through `group_vars`, they override role defaults the normal way, and `host_vars` override `vars` for one host.

## When the roles run

| Event | Runs? |
|---|---|
| First apply, or a host added | Yes, on that host. |
| A change to `roles`, `collections`, `vars`, `sensitive_vars`, that host's entry in `hosts` or `host_vars`, `triggers`, `tags` or `check_mode` | Yes, on the hosts it affects. |
| A host's `triggers` change, such as a VM ID when the VM is replaced | Yes, on that host, with a fresh known_hosts file. |
| Nothing changed | No. The plan shows no changes. |
| A fresh checkout (CI), where `.terraform` starts empty | No. Terraform rewrites the generated files, and the roles and collections are installed again when a run next needs them. |
| `run_on_every_apply = true` | Every apply. |
| A run failed | The next apply tries again: the failed run's resource is tainted. |

A run that needs to happen again, for example after someone changed a host by hand, can be forced:

```bash
terraform apply -replace='module.ssh_bootstrap.ansible_playbook.this["web01"]'
```

## Recipes

### RHEL 8 hosts with only Python 3.6

`libre_devops.python` first, in the same play, with fact gathering off until it has run. It installs a Python ansible-core can use from the host's own repositories (or Satellite), and the next role uses it:

```hcl
module "mde" {
  source  = "libre-devops/role/ansible"
  version = "~> 4.0"

  name         = "mde-linux"
  gather_facts = false
  roles = [
    { name = "libre_devops.python", version = "1.0.0" },
    { name = "libre_devops.mde_linux", version = "1.1.0" },
  ]
  hosts = var.rhel8_hosts

  vars = {
    mde_linux_expected_org_id         = var.mde_org_id
    mde_linux_check_onboarding_org_id = true
  }
  sensitive_vars = {
    mde_linux_onboarding_content = var.mde_onboarding_json
  }
}
```

The module refuses `libre_devops.python` first with `gather_facts = true`, because fact gathering would fail before the role could help.

### Secrets

Put them in `sensitive_vars`, not `vars`: Terraform keeps them out of plan output, and they are written to a file only the current user can read. They are still stored in Terraform state, as every value Terraform manages is, so keep state in a protected backend. Read them from Key Vault or another secret store with a data source, rather than committing them in `.tfvars` files.

### VMs built in the same configuration

Take the address from the VM and put its ID in the host's `triggers`. Terraform then waits for the VM, the roles run when it is first built, and a replaced VM, which keeps its private IP but has a new host key, is configured again with a fresh known_hosts file instead of being refused:

```hcl
hosts = {
  for name, vm in azurerm_linux_virtual_machine.this : name => {
    address          = vm.private_ip_address
    user             = vm.admin_username
    private_key_file = local_sensitive_file.admin_key.filename
    triggers         = { vm_id = vm.id }
  }
}
```

The play waits up to `wait_timeout` seconds for each SSH port to answer before it starts, so a VM that is still booting is not a failure.

### Hosts behind a jump host or Azure Bastion

Pass SSH options through `ssh_common_args`:

```hcl
hosts = {
  app01 = {
    address         = "10.0.2.4"
    user            = "azureuser"
    ssh_common_args = "-o ProxyJump=azureuser@jump.example.com"
  }
}
```

For Microsoft Entra ID sign-in, generate an SSH configuration with `az ssh config --file ssh_config --ip 10.0.2.4` (or `--name` and `--resource-group`) before the apply and pass `ssh_common_args = "-F ssh_config"`.

### Per-host settings

`host_vars` takes a map keyed by host name, with the same variables. `libre_devops.azure_arc` reads its target per host, so each server can get its own resource name and tags:

```hcl
host_vars = {
  web01 = { azure_arc_resource_name = "web01-uks", azure_arc_tags = { role = "web" } }
  db01  = { azure_arc_resource_name = "db01-uks", azure_arc_tags = { role = "database" } }
}
```

A `host_vars` value replaces the `vars` value of the same name. Dictionaries are not merged.

### Roles from git or a private server

Give `src`, and pin a tag or commit with `version`:

```hcl
roles = [{
  name    = "libre_devops.mde_linux"
  src     = "git+https://github.com/libre-devops/ansible-role-mde-linux.git"
  version = "1.1.0"
}]
```

An internal git server or archive URL works the same way. For a private Galaxy or Automation Hub, set `ANSIBLE_GALAXY_SERVER` (and its token) in the environment Terraform runs in; `ansible-galaxy` reads it. Extra collections, or collections from an internal server, go in `collections`.

### Windows hosts

Set `become = false` and `wait_for_ssh = false`, connect with WinRM or PSRP, and add the collection your roles need:

```hcl
become       = false
wait_for_ssh = false
collections  = [{ name = "ansible.windows", version = ">=2.5.0" }]
hosts = {
  win01 = { address = "10.0.3.4", user = "ansibleadmin", connection = "psrp" }
}
sensitive_vars = {
  ansible_password = var.windows_admin_password
}
```

### Check mode first

`check_mode = true` with `diff_mode = true` reports what the roles would change, and changes nothing. Ansible's output is in the `ansible_output` output (sensitive, so read it with `terraform output -json ansible_output`).

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | The host has a new key at an old address, usually a replaced VM. Put the VM's ID in the host's `triggers`, or delete that host's file under `.terraform/ansible/<name>/known_hosts/`. |
| `The module interpreter '/usr/bin/python3' was not found`, or errors about Python 3.6 | The host only has a Python your ansible-core cannot use. Put `libre_devops.python` first, as in [RHEL 8 hosts](#rhel-8-hosts-with-only-python-36). |
| `the role 'x' was not found` | The install failed earlier in the same output, usually Galaxy being unreachable or a wrong `version`. Fix it and apply again: the failed run is retried. |
| A run failed and the error is long | Terraform prints Ansible's whole output. The failing task is the last `fatal:` line. Set `verbosity` for more. |
| Nothing ran after a fresh checkout | That is intended. Runs follow changes, not checkouts. Use `-replace` or `run_on_every_apply` to run anyway. |
| `couldn't find executable` | `ansible-playbook` is not on `PATH` where Terraform runs. Install ansible-core, or set `ansible_playbook_binary`. |

## Limitations

- Each host is a separate `ansible-playbook` run. Tasks marked `run_once` run once per host, and plays cannot use facts from other hosts. Group hosts into one inventory with Ansible itself when a role needs that.
- The provider passes `hostname` as an extra variable on every run, which overrides any variable of that name.
- A run is limited by `timeout` the first time. Later runs are replacements too, so the same limit applies.
- The generated script needs bash, so Terraform must run on Linux or macOS (or WSL). The hosts can be anything Ansible manages.

## Examples

- [`examples/minimal`](./examples/minimal): one role on hosts Terraform can already reach.
- [`examples/complete`](./examples/complete): Defender for Endpoint and then Azure Arc on RHEL 8 hosts, each run with `libre_devops.python` first, secrets in `sensitive_vars` and per-host Arc names and tags.

## Developing

You need Terraform, ansible-core, PowerShell 7+ (for the LibreDevOpsHelpers recipes) and [`just`](https://github.com/casey/just). Run `just` to list the recipes:

- `just validate`: format check, validate, tflint and Trivy for the module and examples.
- `just test`: the plan-time `terraform test` suite, with the providers mocked.
- `just e2e`: the end-to-end test. It starts throwaway SSH containers with podman (Ubuntu 24.04, Debian 13, and Rocky 8 with only Python 3.6), runs Libre DevOps roles from Galaxy through the module, checks their changes, a no-op second plan and a fresh checkout, then destroys everything. CI runs it on every push.
- `just docs`: regenerate the reference section of this README.

Releasing is `just tag-and-release 4.x.y`: plain semver tags, which the Terraform Registry picks up.

## Security scan exceptions

This module is scanned with [Trivy](https://github.com/aquasecurity/trivy); HIGH and CRITICAL findings fail the build. Waivers live in [`.trivyignore.yaml`](./.trivyignore.yaml) and are mirrored here.

| Trivy ID | Resource | Finding | Justification |
|----------|----------|---------|---------------|
| DS-0002 | `tests/e2e/image/Containerfile` | No non-root `USER` | Test fixture only, never published or deployed: the end-to-end test's throwaway SSH hosts run systemd as PID 1, which must be root, so the roles under test can reload services. The test signs in as the unprivileged `ansible` account. |

## Reference

The Requirements, Providers, Inputs, Outputs, and Resources below are generated by `terraform-docs`.
