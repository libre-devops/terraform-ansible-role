output "ansible_output" {
  description = "Map of host name to the ansible-playbook output of its last run. Sensitive, because a role's output can include variable values."
  value       = { for k, v in ansible_playbook.this : k => v.ansible_playbook_stdout }
  sensitive   = true
}

output "hosts" {
  description = "The names of the hosts the roles ran on."
  value       = sort(keys(ansible_playbook.this))
}

output "playbook_path" {
  description = "Path to the generated playbook. Run it by hand with ansible-playbook -i <inventory> <path> to repeat a run outside Terraform."
  value       = local_file.this["playbook.yml"].filename
}

output "run_ids" {
  description = "Map of host name to the ID of its last run, which changes each time the roles run on it."
  value       = { for k, v in ansible_playbook.this : k => v.id }
}

output "working_directory" {
  description = "The directory holding the generated playbook, variables, roles and collections."
  value       = local.work_dir
}
