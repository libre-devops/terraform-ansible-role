# Plan-time tests for the module. The ansible and local providers are mocked, so nothing is
# written and no host is contacted:
#   terraform init -backend=false && terraform test

mock_provider "ansible" {}
mock_provider "local" {}

variables {
  name = "test"
  roles = [
    { name = "libre_devops.python", version = "1.0.0" },
    { name = "libre_devops.mde_linux", version = "1.1.0" },
  ]
  gather_facts = false
  hosts = {
    web01 = { address = "10.0.0.4", user = "azureuser", groups = ["web"], triggers = { vm_id = "vm-1" } }
    db01  = { address = "10.0.0.5", user = "azureuser", port = 2222 }
  }
  vars = {
    mde_linux_onboard = true
    mde_linux_managed_config = {
      antivirusEngine = { enforcementLevel = "real_time" }
    }
  }
  sensitive_vars = { mde_linux_onboarding_content = "{\"onboardingInfo\": \"test\"}" }
  host_vars = {
    db01 = { mde_linux_managed_config_mode = "merge" }
  }
}

run "one_run_per_host" {
  command = plan

  assert {
    condition     = toset(keys(ansible_playbook.this)) == toset(["web01", "db01"])
    error_message = "There should be one ansible_playbook per host, keyed by the host name."
  }

  assert {
    condition     = ansible_playbook.this["web01"].groups == tolist(["web"])
    error_message = "A host's groups should reach its inventory."
  }
}

run "roles_run_in_order_after_the_wait" {
  command = plan

  assert {
    condition     = yamldecode(local.playbook)[1].roles == [{ role = "libre_devops.python" }, { role = "libre_devops.mde_linux" }]
    error_message = "The roles play should run the roles in the order given."
  }

  assert {
    condition     = yamldecode(local.playbook)[0].tasks[0]["ansible.builtin.wait_for"].search_regex == "SSH-"
    error_message = "The first play should wait for an SSH banner."
  }

  assert {
    condition     = yamldecode(local.playbook)[1].gather_facts == false && yamldecode(local.playbook)[1].become == true
    error_message = "The roles play should use gather_facts and become as given."
  }
}

run "no_wait_play_when_switched_off" {
  command = plan

  variables {
    wait_for_ssh = false
  }

  assert {
    condition     = length(yamldecode(local.playbook)) == 1 && yamldecode(local.playbook)[0].name == "test"
    error_message = "With wait_for_ssh false, the playbook should hold only the roles play."
  }
}

run "variables_land_in_group_and_host_vars" {
  command = plan

  assert {
    condition     = jsondecode(local.var_files["group_vars/all.json"]).mde_linux_managed_config.antivirusEngine.enforcementLevel == "real_time"
    error_message = "vars should be written to group_vars/all.json with their structure intact."
  }

  assert {
    condition     = jsondecode(local.var_files["group_vars/all.json"]).mde_linux_onboarding_content == "{\"onboardingInfo\": \"test\"}"
    error_message = "sensitive_vars should be merged into group_vars/all.json."
  }

  assert {
    condition     = jsondecode(local.var_files["host_vars/db01.json"]).mde_linux_managed_config_mode == "merge"
    error_message = "host_vars should be written to that host's file."
  }

  assert {
    condition     = !can(jsondecode(local.var_files["host_vars/web01.json"]).mde_linux_managed_config_mode)
    error_message = "host_vars for one host should not reach another."
  }
}

run "connection_details_reach_host_vars" {
  command = plan

  assert {
    condition     = jsondecode(local.var_files["host_vars/db01.json"]).ansible_host == "10.0.0.5" && jsondecode(local.var_files["host_vars/db01.json"]).ansible_port == 2222
    error_message = "address and port should become ansible_host and ansible_port."
  }

  assert {
    condition     = !can(jsondecode(local.var_files["host_vars/web01.json"]).ansible_port)
    error_message = "Unset connection details should be left out, so Ansible's defaults apply."
  }

  assert {
    condition     = strcontains(jsondecode(local.var_files["host_vars/web01.json"]).ansible_ssh_extra_args, "StrictHostKeyChecking=accept-new")
    error_message = "The default host key checking should be accept-new."
  }
}

run "host_key_checking_off" {
  command = plan

  variables {
    ssh_host_key_checking = "no"
  }

  assert {
    condition     = jsondecode(local.var_files["host_vars/web01.json"]).ansible_host_key_checking == false
    error_message = "ssh_host_key_checking = no should set ansible_host_key_checking to false."
  }

  assert {
    condition     = !can(jsondecode(local.var_files["host_vars/web01.json"]).ansible_ssh_extra_args)
    error_message = "With checking off, no known_hosts arguments should be added."
  }
}

run "new_triggers_start_a_new_known_hosts_file" {
  command = plan

  variables {
    hosts = {
      web01 = { address = "10.0.0.4", user = "azureuser", groups = ["web"], triggers = { vm_id = "vm-2" } }
      db01  = { address = "10.0.0.5", user = "azureuser", port = 2222 }
    }
  }

  assert {
    condition     = local.known_hosts["web01"] != "${local.work_dir}/known_hosts/web01-${substr(sha256(jsonencode(["10.0.0.4", null, { vm_id = "vm-1" }])), 0, 12)}"
    error_message = "A host with new triggers should get a new known_hosts file."
  }
}

run "python_first_needs_gather_facts_off" {
  command = plan

  variables {
    gather_facts = true
  }

  expect_failures = [var.roles]
}

run "a_role_only_once" {
  command = plan

  variables {
    roles = [
      { name = "libre_devops.mde_linux", version = "1.1.0" },
      { name = "libre_devops.mde_linux", version = "1.0.0" },
    ]
  }

  expect_failures = [var.roles]
}

run "host_names_must_be_file_names" {
  command = plan

  variables {
    hosts = { "web 01" = { address = "10.0.0.4" } }
  }

  expect_failures = [var.hosts]
}

run "wrapper_installs_then_runs_ansible_playbook" {
  command = plan

  assert {
    condition     = strcontains(local.wrapper, "exec \"$playbook\" \"$@\"") && strcontains(local.wrapper, "role install --force -r requirements.yml -p roles")
    error_message = "run.sh should install the roles and then hand over to ansible-playbook."
  }

  assert {
    condition     = strcontains(local.wrapper, "want='${sha256(local.requirements)}'")
    error_message = "run.sh should reinstall when requirements.yml changes."
  }
}
