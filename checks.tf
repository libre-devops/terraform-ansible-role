# check blocks run after every plan and apply and warn, without blocking, when something is
# likely to cause trouble.

# A role without a version installs whatever is newest each time the working directory is
# rebuilt (every CI run), so runs stop being repeatable.
check "roles_are_pinned" {
  assert {
    condition     = alltrue([for r in var.roles : r.version != null])
    error_message = "Roles without a version: ${join(", ", [for r in var.roles : r.name if r.version == null])}. Pin each one, such as version = \"1.1.0\", so every run installs the same code."
  }
}

# Windows hosts do not use sudo, so become = true makes every task fail on them.
check "no_become_on_windows" {
  assert {
    condition     = !var.become || alltrue([for h in values(var.hosts) : !contains(["winrm", "psrp", "ansible.builtin.winrm", "ansible.builtin.psrp"], coalesce(h.connection, "ssh"))])
    error_message = "become is true but some hosts connect with WinRM or PSRP. Set become = false for Windows hosts."
  }
}
