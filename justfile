# Libre DevOps Terraform module task runner. Run `just` to list recipes.
#
# Install just with either:
#   brew install just
#   uv tool add rust-just     # then call recipes as: uv run just <recipe>
#
# validate, scan and docs wrap the LibreDevOpsHelpers engine functions in PowerShell, as in the
# other Libre DevOps modules. This module manages no cloud resources, so instead of plan, apply and
# destroy against a remote backend it has `just e2e`, which runs real roles against containers.

set shell := ["pwsh", "-NoProfile", "-Command"]

workspace := env_var_or_default("TF_WORKSPACE", "dev")

# Tag prefix. Empty for Terraform modules so tags are plain semver (1.2.3), which the Terraform
# Registry requires. GitHub Action repos set this to "v".
tag_prefix := ""

# List available recipes.
default:
    just --list

# Install or force-update LibreDevOpsHelpers (the engine the recipes wrap) from PSGallery.
update-ldo-pwsh:
    if (Get-Module -ListAvailable LibreDevOpsHelpers) { Update-Module LibreDevOpsHelpers -Force; Write-Host 'Updated LibreDevOpsHelpers to the latest from PSGallery.' } else { Install-Module LibreDevOpsHelpers -Scope CurrentUser -Force -AllowClobber; Write-Host 'Installed LibreDevOpsHelpers from PSGallery.' }

# Format every Terraform file in place.
fmt:
    terraform fmt -recursive

# Offline quality gates for the module and its examples: format check, validate, tflint, trivy.
validate:
    #!/usr/bin/env pwsh
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module LibreDevOpsHelpers -Force
    Set-LdoLogFormat -Format Text
    Clear-LdoFinding
    foreach ($path in @('.', 'examples/minimal', 'examples/complete')) {
        Write-Host "== $path =="
        Invoke-LdoTerraformFmtCheck -CodePath $path
        terraform "-chdir=$path" init -backend=false -input=false | Out-Null
        Invoke-LdoTerraformValidate -CodePath $path
        Invoke-LdoTfLint -CodePath $path
        Invoke-LdoTrivy -CodePath $path
    }
    Show-LdoFindingsSummary

# Trivy config scan over the module and its examples (no init or cloud needed). Gates on
# HIGH,CRITICAL like the action; a subset of `validate` for when you only want the security scan.
scan:
    #!/usr/bin/env pwsh
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module LibreDevOpsHelpers -Force
    Set-LdoLogFormat -Format Text
    Clear-LdoFinding
    foreach ($path in @('.', 'examples/minimal', 'examples/complete')) {
        Write-Host "== $path =="
        Invoke-LdoTrivy -CodePath $path
    }
    Show-LdoFindingsSummary

# Run PSScriptAnalyzer over the repo's PowerShell scripts using the repo settings. Fails on Error.
pwsh-analyze:
    #!/usr/bin/env pwsh
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) { Install-Module PSScriptAnalyzer -MinimumVersion 1.21.0 -Force -Scope CurrentUser }
    $scripts = Get-ChildItem -Path . -Filter *.ps1 -File
    if (-not $scripts) { Write-Host 'No PowerShell scripts to analyze.'; return }
    $results = $scripts | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Settings ./PSScriptAnalyzerSettings.psd1 }
    if (@($results | Where-Object { $_.Severity -eq 'Error' }).Count -gt 0) {
        $results | Format-Table -AutoSize | Out-String | Write-Host
        throw 'PSScriptAnalyzer found errors.'
    }
    Write-Host 'PSScriptAnalyzer: clean.'

# Run the native terraform tests (plan-time, mocked provider, no cloud credentials).
test:
    terraform init -backend=false -input=false | Out-Null
    terraform test

# Sort variables/outputs, format, and regenerate the README from HEADER.md.
docs:
    ./Sort-LdoTerraform.ps1 -IncludeExamples

# Needs podman, terraform, ansible-core and ssh, and CI runs the same script. It checks the roles'
# changes, a no-op second plan and a fresh checkout, then destroys everything.
# End-to-end test: Libre DevOps roles from Galaxy, run through the module on throwaway SSH containers.
e2e:
    bash tests/e2e/run.sh

# --- Release management -------------------------------------------------------------------
# Tags are plain semver (1.2.3) so the Terraform Registry picks them up. Pass a bare version like
# 1.2.3; the tag_prefix variable (empty here) is applied automatically. Action repos set
# tag_prefix to "v" and use force-push-tag to move a moving major alias.

# Create and push an annotated tag. Example: just tag 1.2.3
tag version:
    git tag -a '{{ tag_prefix }}{{ version }}' -m 'Release {{ tag_prefix }}{{ version }}'
    git push origin '{{ tag_prefix }}{{ version }}'

# Bump the latest semver tag and push the new tag. level = patch (default), minor, or major.
increment-tag level="patch":
    $p = '{{ tag_prefix }}'; $re = '^' + [regex]::Escape($p) + '\d+\.\d+\.\d+$'; $tags = @(git tag --list | Where-Object { $_ -match $re }); $cur = if ($tags.Count -eq 0) { [version]'0.0.0' } else { ($tags | ForEach-Object { [version]($_.Substring($p.Length)) } | Sort-Object)[-1] }; $next = switch ('{{ level }}') { 'major' { "$($cur.Major + 1).0.0" } 'minor' { "$($cur.Major).$($cur.Minor + 1).0" } 'patch' { "$($cur.Major).$($cur.Minor).$($cur.Build + 1)" } default { throw 'level must be patch, minor, or major' } }; $tag = "$p$next"; git tag -a $tag -m "Release $tag"; git push origin $tag; Write-Host "Tagged and pushed $tag"

# Create a GitHub release from an existing tag, with auto-generated notes. Example: just release 1.2.3
release version:
    gh release create '{{ tag_prefix }}{{ version }}' --title '{{ tag_prefix }}{{ version }}' --generate-notes

# Tag a specific version and release it. Example: just tag-and-release 1.2.3
tag-and-release version:
    git tag -a '{{ tag_prefix }}{{ version }}' -m 'Release {{ tag_prefix }}{{ version }}'
    git push origin '{{ tag_prefix }}{{ version }}'
    gh release create '{{ tag_prefix }}{{ version }}' --title '{{ tag_prefix }}{{ version }}' --generate-notes

# Bump the latest tag, push it, and create a release. level = patch (default), minor, or major.
increment-release level="patch":
    $p = '{{ tag_prefix }}'; $re = '^' + [regex]::Escape($p) + '\d+\.\d+\.\d+$'; $tags = @(git tag --list | Where-Object { $_ -match $re }); $cur = if ($tags.Count -eq 0) { [version]'0.0.0' } else { ($tags | ForEach-Object { [version]($_.Substring($p.Length)) } | Sort-Object)[-1] }; $next = switch ('{{ level }}') { 'major' { "$($cur.Major + 1).0.0" } 'minor' { "$($cur.Major).$($cur.Minor + 1).0" } 'patch' { "$($cur.Major).$($cur.Minor).$($cur.Build + 1)" } default { throw 'level must be patch, minor, or major' } }; $tag = "$p$next"; git tag -a $tag -m "Release $tag"; git push origin $tag; gh release create $tag --title $tag --generate-notes; Write-Host "Released $tag"

# Bump, tag, and release in one step (same as increment-release). Example: just increment-tag-and-release minor
increment-tag-and-release level="patch":
    just increment-release {{ level }}

# Force-update a tag to a ref and push it (literal tag), for example a moving major alias.
force-push-tag tag ref="HEAD":
    git tag -f '{{ tag }}' '{{ ref }}'
    git push -f origin '{{ tag }}'
    @echo "Force-pushed {{ tag }} to {{ ref }}"
