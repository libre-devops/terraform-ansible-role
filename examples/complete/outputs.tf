output "arc_hosts" {
  description = "The hosts Azure Arc was set up on."
  value       = module.arc.hosts
}

output "arc_run_ids" {
  description = "Map of host name to the ID of its last Azure Arc run."
  value       = module.arc.run_ids
}

output "mde_hosts" {
  description = "The hosts Defender for Endpoint was set up on."
  value       = module.mde.hosts
}

output "mde_run_ids" {
  description = "Map of host name to the ID of its last Defender for Endpoint run."
  value       = module.mde.run_ids
}
