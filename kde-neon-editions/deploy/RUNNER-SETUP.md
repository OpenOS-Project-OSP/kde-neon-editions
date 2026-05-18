# ISO Builder — Plug-and-Play Setup

ISO builds use `live-build`, which requires loop devices and chroot inside a
VM. Pick whichever path fits your situation — all three produce the same
`.iso` + `.iso.sha256` artifact.

---

## Quick-start decision tree

```
Do you want CI/CD builds (automated, nightly)?
├── Yes → Do you have a machine available?
│         ├── Yes (Linux VM or bare metal)  → Path A: register-runner.sh
│         └── No — spin one up:
│               ├── Hetzner / DO / AWS      → Path B: Terraform (supported providers)
│               └── Any other provider      → Path C: Terraform (generic / BYO)
└── No  → Path D: local-build.sh (build on your laptop/workstation)
```

---

## Path A — Register any Linux machine as a runner

One script. Works on Ubuntu, Debian, Fedora, RHEL, Arch, and derivatives.
Detects the OS, installs `live-build` and `gitlab-runner`, configures sudo,
and registers the runner — no manual steps.

### 1. Get a runner token

Go to:
```
https://gitlab.com/groups/openos-project/kde-ecosystem-deving/neon-deving/-/runners/new
```
Copy the token (starts with `glrt-`).

### 2. Run the script

**One-liner (no clone needed):**
```bash
curl -fsSL \
  https://gitlab.com/openos-project/kde-ecosystem-deving/neon-deving/kde-neon-editions/-/raw/main/deploy/register-runner.sh \
  | GITLAB_RUNNER_TOKEN="glrt-YOUR-TOKEN-HERE" sh
```

**Or from a local clone:**
```bash
GITLAB_RUNNER_TOKEN="glrt-YOUR-TOKEN-HERE" bash deploy/register-runner.sh
```

**Optional environment variables:**
| Variable | Default | Description |
|---|---|---|
| `RUNNER_NAME` | `hostname-iso-builder` | Name shown in GitLab UI |
| `RUNNER_CONCURRENT` | `1` | Concurrent builds (increase if disk ≥ 80 GB) |
| `RUNNER_TAGS` | `privileged,iso-builder,neon` | GitLab runner tags |
| `SKIP_DEPS` | `0` | Set `1` to skip package installation |
| `SKIP_REGISTER` | `0` | Set `1` to only install deps |

### Minimum machine requirements

| Resource | Minimum | Recommended |
|---|---|---|
| CPU | 2 vCPU | 4 vCPU |
| RAM | 6 GB | 8 GB |
| Disk | 40 GB free | 80 GB (for 2 concurrent builds) |
| OS | Ubuntu 22.04+ / Debian 12+ | Ubuntu 24.04 Noble |
| KVM | Optional (faster) | Recommended |

### 3. Verify

The runner appears at:
```
https://gitlab.com/groups/openos-project/kde-ecosystem-deving/neon-deving/-/runners
```
Status should be `online` within ~30 seconds.

---

## Path B — Provision a cloud VM with Terraform

No machine? Terraform provisions one on Hetzner, DigitalOcean, or AWS,
injects cloud-init, and the VM registers itself as a runner on first boot.

### 1. Get a runner token (same as Path A step 1)

### 2. Choose a provider and copy its `.tfvars`

```bash
# Hetzner (~€8/mo for cx32 — recommended for cost)
cp deploy/terraform/providers/hetzner.tfvars deploy/terraform/terraform.tfvars

# DigitalOcean (~$48/mo for s-4vcpu-8gb)
cp deploy/terraform/providers/digitalocean.tfvars deploy/terraform/terraform.tfvars

# AWS (~$0.17/hr for t3.xlarge on-demand, cheaper on spot)
cp deploy/terraform/providers/aws.tfvars deploy/terraform/terraform.tfvars
```

### 3. Fill in the two required tokens

Edit `deploy/terraform/terraform.tfvars`:
```hcl
gitlab_runner_token = "glrt-YOUR-TOKEN-HERE"
hetzner_token       = "YOUR-HETZNER-API-TOKEN"   # or digitalocean_token / aws_access_key+secret_key
```

### 4. Apply

```bash
terraform -chdir=deploy/terraform init
terraform -chdir=deploy/terraform apply
```

Terraform outputs the VM IP and a link to verify the runner in GitLab.
The runner comes online within ~5 minutes of `apply` completing.

### 5. Tear down when not needed

```bash
terraform -chdir=deploy/terraform destroy
```

No idle cost — spin up for a build run, destroy after.

### Provider comparison

| Provider | Instance | vCPU | RAM | Cost | Notes |
|---|---|---|---|---|---|
| Hetzner | cx32 | 4 | 8 GB | ~€8/mo | Best value, EU datacentres |
| Hetzner | cx42 | 8 | 16 GB | ~€14/mo | For concurrent builds |
| DigitalOcean | s-4vcpu-8gb | 4 | 8 GB | ~$48/mo | Simple API |
| AWS | t3.xlarge | 4 | 16 GB | ~$0.17/hr | Spot ~$0.05/hr |
| AWS | t3.2xlarge | 8 | 32 GB | ~$0.33/hr | Spot ~$0.10/hr |

---

## Path C — Provision a VM on any other cloud provider (generic Terraform)

Use this when your provider is not Hetzner, DigitalOcean, or AWS — for
example Vultr, OVHcloud, Linode/Akamai, Scaleway, Exoscale, UpCloud,
Azure, GCP, Oracle Cloud, Proxmox, or any KVM/libvirt host.

This mode does not provision a VM. Instead it renders the cloud-init
user-data to a local file that you inject into your provider's console,
API, or your own Terraform resource block.

### 1. Get a runner token (same as Path A step 1)

### 2. Configure and render

```bash
cp deploy/terraform/providers/generic.tfvars deploy/terraform/terraform.tfvars
```

Edit `deploy/terraform/terraform.tfvars` and set at minimum:
```hcl
gitlab_runner_token = "glrt-YOUR-TOKEN-HERE"
```

Then render the user-data:
```bash
terraform -chdir=deploy/terraform init
terraform -chdir=deploy/terraform apply
```

This writes `deploy/cloud-init/rendered-user-data.yaml`. No VM is created.

### 3. Provision your VM

Provision a VM on your provider with:
- **OS:** Ubuntu 22.04+ or Debian 12+ (Ubuntu 24.04 recommended)
- **CPU:** 4 vCPU minimum
- **RAM:** 8 GB minimum
- **Disk:** 40 GB minimum free space
- **User data:** paste the contents of `rendered-user-data.yaml` into your
  provider's "user data" / "startup script" / cloud-init field at boot time

The runner installs `live-build` and registers itself with GitLab automatically
on first boot. It appears in the runners list within ~5 minutes.

### 4. Verify (same as Path A step 3)

### Adding your provider to Terraform (optional)

If you want full `terraform apply` / `terraform destroy` lifecycle management,
add a resource block for your provider to `deploy/terraform/main.tf` following
the same pattern as the Hetzner, DigitalOcean, or AWS blocks, and submit a
merge request.

---

## Path D — Build locally (no runner, no cloud account)

Build an ISO directly on your workstation or laptop. No GitLab runner needed.
The script auto-detects whether native `live-build` is available and falls
back to Docker/Podman if not.

### Usage

```bash
# Clone the repo
git clone https://gitlab.com/openos-project/kde-ecosystem-deving/neon-deving/kde-neon-editions.git
cd kde-neon-editions

# Build the User Edition (auto-detects native vs Docker)
bash deploy/local-build.sh --edition user

# Force Docker/Podman mode (works on any OS with Docker installed)
bash deploy/local-build.sh --edition user --docker

# Other editions
bash deploy/local-build.sh --edition testing
bash deploy/local-build.sh --edition developer-stable
bash deploy/local-build.sh --edition developer-unstable

# Options
bash deploy/local-build.sh --edition user --no-cache   # skip debootstrap cache
bash deploy/local-build.sh --edition user --output ~/isos  # custom output dir
bash deploy/local-build.sh --edition user --dry-run    # print commands only
```

### Native mode requirements

- Linux (any distro with `live-build` available)
- `live-build`, `debootstrap`, `xorriso`, `squashfs-tools`
- Loop device access (`losetup -f` must succeed)
- Root or passwordless sudo for `lb`

### Docker/Podman mode requirements

- Docker or Podman installed (any OS including macOS/Windows WSL2)
- `--privileged` container support (standard on Linux; may need config on macOS)
- ~40 GB free disk

### CI fallback: `NO_RUNNER=true`

If no `iso-builder` runner is online, trigger a pipeline with
`NO_RUNNER=true` to get a job that prints the exact local-build commands
for that edition (useful while setting up a runner via Path A, B, or C):

```
https://gitlab.com/openos-project/kde-ecosystem-deving/neon-deving/neon-user/-/pipelines/new
```
Set variable `NO_RUNNER` = `true`.

---

## garm-gitlab auto-scaling pool (advanced)

For teams that want fully automated, on-demand VM provisioning without
managing Terraform state, `garm-gitlab` provisions Incus VMs per job and
destroys them after. See:

- `deploy/garm-pool-iso-builder.yaml` — pool configuration
- `deploy/incus-profile-iso-builder.yaml` — Incus VM profile
- `ci/runners/garm-gitlab/deploy/SETUP.md` in the `gitlab-enhanced` repo

---

## Verifying a build

Once any runner is online, trigger a manual build:

```
https://gitlab.com/openos-project/kde-ecosystem-deving/neon-deving/neon-user/-/pipelines/new
```

The `build-user-iso` job runs manually on push to `main`. It takes 20–40
minutes and produces a `.iso` + `.iso.sha256` artifact downloadable from
the pipeline's Artifacts section.
