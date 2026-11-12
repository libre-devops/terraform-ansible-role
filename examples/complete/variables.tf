variable "arc_location" {
  description = "Azure region for the Arc-enabled server resources."
  type        = string
  default     = "uksouth"
}

variable "arc_resource_group" {
  description = "Resource group for the Arc-enabled server resources."
  type        = string
}

variable "arc_service_principal_id" {
  description = "Application (client) ID of the service principal that onboards the servers to Azure Arc."
  type        = string
}

variable "arc_service_principal_secret" {
  description = "Secret of the Arc onboarding service principal."
  type        = string
  sensitive   = true
}

variable "arc_subscription_id" {
  description = "Subscription for the Arc-enabled server resources."
  type        = string
}

variable "arc_targets" {
  description = "Per-host Azure Arc settings, keyed by the names in hosts: the resource name in Azure and its tags."
  type = map(object({
    resource_name = string
    tags          = optional(map(string), {})
  }))
  default = {}
}

variable "arc_tenant_id" {
  description = "Entra ID tenant for Azure Arc."
  type        = string
}

variable "hosts" {
  description = <<-EOT
    Hosts to configure, keyed by inventory name, as the module's hosts input. For VMs built in
    the same configuration, take address from the VM and put its ID in triggers, so a replaced VM
    is configured again with a fresh host key. To reach private VMs through a jump host or Azure
    Bastion tunnel, set ssh_common_args, for example "-o ProxyJump=jump.example.com".
  EOT
  type = map(object({
    address          = optional(string)
    user             = optional(string)
    port             = optional(number)
    private_key_file = optional(string)
    ssh_common_args  = optional(string)
    groups           = optional(list(string), [])
    triggers         = optional(map(string), {})
  }))
}

variable "mde_onboarding_json" {
  description = "The content of mdatp_onboard.json from the Defender portal (Linux Server, Your preferred Linux configuration management tool)."
  type        = string
  sensitive   = true
}

variable "mde_org_id" {
  description = "Your Defender for Endpoint organisation ID. The role refuses an onboarding package for any other organisation."
  type        = string
}
