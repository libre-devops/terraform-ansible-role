variable "ansible_galaxy_binary" {
  description = "The ansible-galaxy command that installs the roles and collections, by name on PATH or as a path."
  type        = string
  default     = "ansible-galaxy"
}

variable "ansible_playbook_binary" {
  description = "The ansible-playbook command that runs the roles, by name on PATH or as a path."
  type        = string
  default     = "ansible-playbook"
}

variable "become" {
  description = "Run the roles with privilege escalation (sudo by default). Set false for Windows hosts, and for roles that escalate where they need to."
  type        = bool
  default     = true
}

variable "check_mode" {
  description = "Run in check mode: Ansible reports what it would change and changes nothing."
  type        = bool
  default     = false
}

variable "collections" {
  description = <<-EOT
    Collections to install as well as the ones each role lists in its own requirements.yml (the
    Libre DevOps roles list theirs). Each entry: name (namespace.collection), and optionally
    version (a version or range, such as ">=1.6.0") and source (a Galaxy server or a path or URL
    to a collection archive).
  EOT
  type = list(object({
    name    = string
    version = optional(string)
    source  = optional(string)
  }))
  default = []

  validation {
    condition     = alltrue([for c in var.collections : can(regex("^[a-z0-9_]+\\.[a-z0-9_]+$", c.name)) || c.source != null])
    error_message = "Each collections[*].name must be namespace.collection, unless source gives where it comes from."
  }
}

variable "diff_mode" {
  description = "Show the differences in the files the roles change. Most useful with check_mode."
  type        = bool
  default     = false
}

variable "gather_facts" {
  description = "Gather facts before the roles run. Must be false when libre_devops.python runs first, because it gives hosts the Python that fact gathering needs."
  type        = bool
  default     = true
}

variable "host_vars" {
  description = <<-EOT
    Role variables for single hosts, keyed by the names in hosts, in the same form as vars. They
    are written to host_vars, so they take precedence over vars.
  EOT
  type        = any
  default     = {}

  validation {
    condition     = can(keys(var.host_vars))
    error_message = "host_vars must be a map or object keyed by host name."
  }
}

variable "hosts" {
  description = <<-EOT
    Hosts to run the roles on, keyed by inventory name. Each entry is how Ansible reaches the
    host: address (ansible_host, default the key), user, port, private_key_file, ssh_common_args
    and ssh_extra_args (for example a ProxyCommand through a jump host), connection (ssh unless
    set, such as winrm or psrp for Windows), python_interpreter, groups (inventory groups the
    host is in), and triggers (values, such as the VM's ID, that run the roles again and start a
    new known_hosts file when they change).
  EOT
  type = map(object({
    address            = optional(string)
    user               = optional(string)
    port               = optional(number)
    private_key_file   = optional(string)
    ssh_common_args    = optional(string)
    ssh_extra_args     = optional(string)
    connection         = optional(string)
    python_interpreter = optional(string)
    groups             = optional(list(string), [])
    triggers           = optional(map(string), {})
  }))

  validation {
    condition     = length(var.hosts) > 0
    error_message = "hosts must name at least one host."
  }

  validation {
    condition     = alltrue([for name in keys(var.hosts) : can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", name))])
    error_message = "Each hosts key is an inventory name and a file name: letters, digits, dots, dashes and underscores, starting with a letter or digit."
  }
}

variable "name" {
  description = "Name of this run: the play's name, and the directory under .terraform/ansible that holds the playbook, roles and collections. Unique within the root module."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.name))
    error_message = "name must be letters, digits, dots, dashes and underscores, starting with a letter or digit."
  }
}

variable "roles" {
  description = <<-EOT
    Roles to run, in order, in one play. Each entry: name (a Galaxy role such as
    libre_devops.mde_linux, or the name to give a role from src), version (the Galaxy version or
    git ref to pin; strongly recommended), src (a git URL or archive URL instead of Galaxy, such
    as git+https://github.com/libre-devops/ansible-role-mde-linux.git) and scm (git, when src
    is a git URL without the git+ prefix).
  EOT
  type = list(object({
    name    = string
    version = optional(string)
    src     = optional(string)
    scm     = optional(string)
  }))

  validation {
    condition     = length(var.roles) > 0
    error_message = "roles must name at least one role."
  }

  validation {
    condition     = length(distinct([for r in var.roles : r.name])) == length(var.roles)
    error_message = "Each role can appear only once in roles."
  }

  validation {
    condition     = alltrue([for r in var.roles : can(regex("^[A-Za-z0-9_.-]+$", r.name))])
    error_message = "Each roles[*].name must be a role name such as libre_devops.mde_linux, not a path or URL (put a URL in src)."
  }

  validation {
    condition     = !(var.gather_facts && var.roles[0].name == "libre_devops.python")
    error_message = "libre_devops.python runs first, so set gather_facts = false: it gives hosts the Python that fact gathering needs."
  }
}

variable "run_on_every_apply" {
  description = "Run the roles on every apply, not only when the roles, variables, hosts or triggers change. The plan then always shows the runs."
  type        = bool
  default     = false
}

variable "sensitive_vars" {
  description = "Role variables that are secrets, such as an onboarding package's content. Merged over vars, kept out of plan output, and written to a file only the current user can read."
  type        = any
  default     = {}
  sensitive   = true
}

variable "ssh_host_key_checking" {
  description = <<-EOT
    How SSH treats host keys: accept-new (trust a host's key the first time and refuse a changed
    one, using a known_hosts file per host under the working directory), yes (only hosts already
    in your known_hosts) or no (never check; avoid outside throwaway hosts).
  EOT
  type        = string
  default     = "accept-new"

  validation {
    condition     = contains(["accept-new", "yes", "no"], var.ssh_host_key_checking)
    error_message = "ssh_host_key_checking must be accept-new, yes or no."
  }
}

variable "tags" {
  description = "Run only the role tasks with these Ansible tags."
  type        = list(string)
  default     = []
}

variable "timeout" {
  description = "How long the first run on a host may take before Terraform gives up, such as 30m or 2h."
  type        = string
  default     = "60m"
}

variable "triggers" {
  description = "Values that run the roles again on every host when they change, as well as changes to the roles, variables and hosts."
  type        = map(string)
  default     = {}
}

variable "vars" {
  description = <<-EOT
    Role variables, as you would write them in YAML: strings, numbers, booleans, lists and maps,
    such as { mde_linux_managed_config = { antivirusEngine = { enforcementLevel = "real_time" } } }.
    Written to group_vars/all next to the playbook, so they override role defaults the normal way.
  EOT
  type        = any
  default     = {}

  validation {
    condition     = can(keys(var.vars))
    error_message = "vars must be a map or object of variable names to values."
  }
}

variable "verbosity" {
  description = "Ansible verbosity, from 0 (normal) to 6 (-vvvvvv)."
  type        = number
  default     = 0

  validation {
    condition     = var.verbosity >= 0 && var.verbosity <= 6
    error_message = "verbosity must be between 0 and 6."
  }
}

variable "wait_for_ssh" {
  description = "Before the roles run, wait until each SSH host's port answers with an SSH banner, checked from the control node, so a host that is still booting is not a failure."
  type        = bool
  default     = true
}

variable "wait_timeout" {
  description = "Seconds to wait for each host's SSH port when wait_for_ssh is true."
  type        = number
  default     = 600
}

variable "working_directory" {
  description = "Directory for the generated playbook, variables, roles and collections. Default: .terraform/ansible/<name> in the root module, which Git already ignores."
  type        = string
  default     = null
}
