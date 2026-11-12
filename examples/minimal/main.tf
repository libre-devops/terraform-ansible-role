# Minimal call: one Libre DevOps role from Galaxy on hosts Terraform can already reach over SSH.
# It adds SSH keys for the admin account and hardens sshd, then changes nothing on later applies
# until a role, variable or host changes.
module "this" {
  source = "../../"

  name  = "ssh-bootstrap"
  roles = [{ name = "libre_devops.ssh_bootstrap", version = "1.0.0" }]
  hosts = var.hosts

  vars = {
    ssh_bootstrap_authorized_keys = [
      { user = var.admin_user, keys = var.authorized_keys },
    ]
    ssh_bootstrap_sshd_settings = {
      PermitEmptyPasswords   = false
      PermitRootLogin        = false
      PasswordAuthentication = false
    }
  }
}
