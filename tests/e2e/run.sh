#!/usr/bin/env bash
#
# End-to-end test: runs the Libre DevOps roles from Galaxy through this module against
# throwaway SSH containers, then checks the module's promises.
#
#   1. The first apply configures every host, including a RHEL 8 family host with only
#      Python 3.6 (libre_devops.python runs first), and the roles' changes are in effect.
#   2. A second plan has nothing to do.
#   3. On a fresh checkout (no .terraform/ansible) Terraform rewrites the generated files and
#      runs nothing, and the next plan is empty again.
#   4. Destroy removes everything.
#
# Needs podman (for systemd in the containers), terraform, ansible-core, ssh and ssh-keygen,
# and access to Galaxy and the distributions' package mirrors. Used by `just e2e` and CI.

set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HERE
readonly PREFIX="ldo-tfa-e2e"
readonly HOSTS=(
  "ubuntu2404|docker.io/library/ubuntu:24.04|debian|2231"
  "debian13|docker.io/library/debian:13|debian|2232"
  "rocky8|docker.io/rockylinux/rockylinux:8-ubi-init|rhel|2233"
)

WORK="$(mktemp -d)"
readonly WORK

#######################################
# Remove the containers, the generated state and the working files.
#######################################
cleanup() {
  local entry
  for entry in "${HOSTS[@]}"; do
    podman rm -f -t 0 "${PREFIX}-${entry%%|*}" >/dev/null 2>&1 || true
  done
  rm -rf "${HERE}/.terraform" "${HERE}/.terraform.lock.hcl" "${HERE}/backend_override.tf" \
    "${HERE}/e2e.auto.tfvars" "${WORK}"
}
trap cleanup EXIT

#######################################
# Print a step heading.
#######################################
step() {
  printf '\n==> %s\n' "$*"
}

#######################################
# Run a command on a test host as ansible with the given key.
# Arguments: port, key file, command
#######################################
on_host() {
  ssh -i "$2" -p "$1" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR ansible@127.0.0.1 "$3"
}

#######################################
# Fail unless a plan has no changes.
#######################################
expect_empty_plan() {
  local rc=0
  terraform -chdir="${HERE}" plan -detailed-exitcode -input=false -no-color >"${WORK}/plan.log" 2>&1 || rc=$?
  if [[ "${rc}" -ne 0 ]]; then
    cat "${WORK}/plan.log"
    echo "Expected a plan with no changes (exit 0), got exit ${rc}." >&2
    exit 1
  fi
}

step "Generating test keys"
ssh-keygen -q -t ed25519 -N "" -C "${PREFIX}" -f "${WORK}/id"
ssh-keygen -q -t ed25519 -N "" -C "${PREFIX}-second" -f "${WORK}/id_second"
mkdir -p "${WORK}/image"
cp "${HERE}/image/Containerfile" "${WORK}/image/"
cp "${WORK}/id.pub" "${WORK}/image/authorized_keys"

step "Starting the SSH containers"
tfvars="hosts = {"
for entry in "${HOSTS[@]}"; do
  IFS='|' read -r name base family port <<<"${entry}"
  podman build -q --build-arg "BASE=${base}" --build-arg "FAMILY=${family}" \
    -t "localhost/${PREFIX}-${name}" "${WORK}/image" >/dev/null
  podman rm -f -t 0 "${PREFIX}-${name}" >/dev/null 2>&1 || true
  podman run -d --name "${PREFIX}-${name}" --systemd=always -p "127.0.0.1:${port}:22" \
    "localhost/${PREFIX}-${name}" >/dev/null
  id="$(podman inspect -f '{{.Id}}' "${PREFIX}-${name}")"
  tfvars+="
  ${name} = { address = \"127.0.0.1\", port = ${port}, user = \"ansible\", private_key_file = \"${WORK}/id\", family = \"${family}\", machine_id = \"${id:0:12}\" }"
done
tfvars+="
}
second_key = \"$(cat "${WORK}/id_second.pub")\""
printf '%s\n' "${tfvars}" >"${HERE}/e2e.auto.tfvars"
printf 'terraform {\n  backend "local" {\n    path = "%s/terraform.tfstate"\n  }\n}\n' "${WORK}" \
  >"${HERE}/backend_override.tf"

step "1. First apply"
terraform -chdir="${HERE}" init -input=false -no-color >/dev/null
terraform -chdir="${HERE}" apply -auto-approve -input=false -no-color

step "Checking the roles' changes are in effect"
for entry in "${HOSTS[@]}"; do
  IFS='|' read -r name _ family port <<<"${entry}"
  on_host "${port}" "${WORK}/id_second" 'sudo sshd -T | grep -qi "^maxauthtries 4$"'
  echo "${name}: signs in with the key the role added, and sshd uses MaxAuthTries 4"
  if [[ "${family}" == "rhel" ]]; then
    on_host "${port}" "${WORK}/id_second" 'ls /usr/bin/python3.* >/dev/null'
    echo "${name}: libre_devops.python installed a Python Ansible can use"
  fi
done

step "2. A second plan has nothing to do"
expect_empty_plan
echo "No changes."

step "3. A fresh checkout rewrites the generated files and runs nothing"
rm -rf "${HERE}/.terraform/ansible"
terraform -chdir="${HERE}" apply -auto-approve -input=false -no-color | tee "${WORK}/fresh.log"
if grep -q 'ansible_playbook.this\[.*\]: Creating' "${WORK}/fresh.log"; then
  echo "A fresh checkout ran the roles again." >&2
  exit 1
fi
expect_empty_plan
echo "Files rewritten, no runs, and the next plan is empty."

step "4. Destroy"
terraform -chdir="${HERE}" destroy -auto-approve -input=false -no-color >/dev/null
echo "Destroyed."

step "End-to-end test passed"
