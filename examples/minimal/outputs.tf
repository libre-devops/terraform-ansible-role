output "hosts" {
  description = "The hosts the role ran on."
  value       = module.this.hosts
}

output "playbook_path" {
  description = "The generated playbook, for running the same thing by hand."
  value       = module.this.playbook_path
}

output "run_ids" {
  description = "Map of host name to the ID of its last run."
  value       = module.this.run_ids
}
