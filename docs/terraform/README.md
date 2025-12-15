# Terraform Infrastructure as Code

This directory contains Terraform-based infrastructure provisioning guides
for the MCPaaS project. Each subdirectory represents a deployable infrastructure
component with complete Terraform configuration files.

## Available Configurations

### Create_Resource_Group

**Path:** `docs/terraform/Create_Resource_Group/`  
**Documentation:** `docs/terraform/Create_Resource_Group.md`

Creates a reusable Azure Resource Group that serves as a container for other
Azure resources:
- Single resource group with tags
- Configurable location and naming
- Outputs for downstream consumption
- Demonstrates Terraform idempotency

**Use Case:** Foundation for AKS, ACR, and other Azure services.

**Quick Start:**

```bash
cd docs/terraform/Create_Resource_Group
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Azure subscription ID
terraform init
terraform apply
```

### Create_AKS

**Path:** `docs/terraform/Create_AKS/`  
**Documentation:** `docs/terraform/Create_AKS.md`

**Prerequisites:** Requires `Create_Resource_Group` to be completed first.

Provisions an Azure Kubernetes Service (AKS) cluster with:
- AKS cluster with system node pool
- Optional user node pool
- Managed identity
- Azure CNI networking

This is the Terraform equivalent of `docs/Create_AKS.md`, providing
infrastructure-as-code benefits over imperative bash scripting.

**Unique Feature:** Uses an **incremental building approach** where you create
`aks.tf` from scratch, adding resources one at a time. Uses data source to
reference the existing resource group, demonstrating loose coupling between
Terraform workspaces.

**Quick Start (Incremental Learning Path):**

```bash
# First, create the resource group
cd docs/terraform/Create_Resource_Group
cp terraform.tfvars.example terraform.tfvars
# Edit with your subscription ID
terraform init && terraform apply

# Then, create the AKS cluster
cd ../Create_AKS
cp terraform.tfvars.example terraform.tfvars
# Edit with subscription ID and resource group name  
terraform init
# Follow the guide to build aks.tf step-by-step
```

**Quick Start (Skip to Complete):**

```bash
# First, create the resource group
cd docs/terraform/Create_Resource_Group
cp terraform.tfvars.example terraform.tfvars && terraform init && terraform apply

# Then, create the AKS cluster
cd ../Create_AKS
cp terraform.tfvars.example terraform.tfvars
cp aks-step2-user-nodepool.tf.example aks.tf
terraform init && terraform apply
```

## Why Terraform?

Terraform provides several advantages for infrastructure management:

- **Declarative Configuration** - Define desired state, not steps to achieve it
- **State Management** - Track infrastructure state for safe updates and drift detection
- **Change Preview** - See exactly what will change before applying
- **Idempotency** - Safe to run multiple times without duplication
- **Version Control** - Infrastructure configuration lives alongside application code
- **Team Collaboration** - Code review for infrastructure changes
- **Reusability** - Modules enable DRY infrastructure patterns

## When to Use Terraform vs Bash

**Use Terraform when:**
- Managing long-lived production infrastructure
- Working in teams requiring change review
- Need state tracking and drift detection
- Want infrastructure versioned alongside code
- Require preview-before-apply safety

**Use Bash (docs/*.md) when:**
- Learning Azure and AKS concepts interactively
- One-off experimental clusters
- Dynamic scripting and automation
- Minimal tooling dependencies preferred
- Quick prototyping and exploration

Both approaches are valid and serve different use cases.

## Prerequisites

All Terraform configurations in this directory require:

- **Terraform** >= 1.5.0
- **Azure CLI** (`az`) authenticated with appropriate permissions
- **kubectl** for cluster verification
- **Azure subscription** with sufficient quota

Install Terraform:
```bash
# macOS
brew install terraform

# Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify installation
terraform version
```

## General Workflow

Each Terraform configuration follows this standard workflow:

1. **Navigate** to the configuration directory
   ```bash
   cd docs/terraform/<config-name>
   ```

2. **Configure** variables in `terraform.tfvars`
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Initialize** Terraform
   ```bash
   terraform init
   ```

4. **Plan** changes
   ```bash
   terraform plan -out=tfplan
   ```

5. **Apply** configuration
   ```bash
   terraform apply tfplan
   ```

6. **Verify** deployment
   ```bash
   terraform output
   # Use kubectl or az CLI for additional verification
   ```

7. **Manage** infrastructure
   ```bash
   # Make changes to .tf files or terraform.tfvars
   terraform plan
   terraform apply
   ```

8. **Destroy** when finished
   ```bash
   terraform destroy
   ```

## File Structure

Each Terraform configuration typically includes:

```
<config-name>/
├── providers.tf           # Provider configuration and versions
├── variables.tf           # Input variables and defaults
├── main.tf               # Core resource definitions
├── outputs.tf            # Output values
├── terraform.tfvars.example  # Example variable values
├── .gitignore           # Excludes state and sensitive files
└── README.md            # Configuration-specific documentation
```

## State Management

### Local State (Default)

By default, Terraform stores state locally in `terraform.tfstate`. This is
suitable for individual use but has limitations for team collaboration.

**Important:** Local state files are git-ignored and contain sensitive data.
Never commit them to version control.

### Remote State (Recommended for Teams)

For team environments, consider using remote state backends:

- **Azure Storage** - Native Azure integration
- **Terraform Cloud** - HashiCorp's managed service
- **S3** - AWS-based storage
- **Consul** - For advanced use cases

Example Azure Storage backend configuration:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstate<unique-id>"
    container_name       = "tfstate"
    key                  = "aks.terraform.tfstate"
  }
}
```

See [Terraform Backend Documentation](https://developer.hashicorp.com/terraform/language/settings/backends/configuration)
for configuration details.

## Best Practices

1. **Always run `terraform plan`** before applying changes
2. **Review plan output carefully** to understand what will change
3. **Use variables** for environment-specific values
4. **Tag resources** for cost tracking and management
5. **Version providers** to ensure reproducible deployments
6. **Use `.gitignore`** to exclude state and sensitive files
7. **Document outputs** for downstream consumers
8. **Organize files** by logical concern (providers, variables, resources, outputs)
9. **Use modules** for reusable infrastructure patterns
10. **Store state remotely** for team collaboration

## Security Considerations

- **Never commit** `terraform.tfvars` if it contains sensitive data
- **Never commit** `terraform.tfstate` files (contain sensitive outputs)
- **Use Azure Key Vault** for secrets and certificates
- **Enable state encryption** when using remote backends
- **Restrict provider credentials** to minimum required permissions
- **Review plans** before applying to catch unintended changes
- **Use workspaces** to isolate environments (dev, staging, prod)

## Troubleshooting

### Common Issues

**Provider initialization fails:**
```bash
terraform init -upgrade
```

**State conflicts:**
```bash
# If working alone and state is corrupted
terraform state pull
terraform refresh
```

**Plan shows unexpected changes:**
```bash
# View current state
terraform show

# Compare with Azure
terraform plan
```

**Authentication errors:**
```bash
az login
az account show
```

### Getting Help

- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform AKS Examples](https://github.com/hashicorp/terraform-provider-azurerm/tree/main/examples/kubernetes)

## Contributing

When adding new Terraform configurations:

1. Create a dedicated subdirectory under `docs/terraform/`
2. Include all standard files (providers, variables, main, outputs)
3. Provide `.gitignore` and `terraform.tfvars.example`
4. Write comprehensive documentation in a corresponding `.md` file
5. Follow existing naming conventions and file organization
6. Add entry to this README under "Available Configurations"
7. Test the complete workflow from init to destroy
8. Document prerequisites and expected outcomes

## Future Configurations

Planned Terraform configurations for this directory:

- **Deploy_ACR** - Azure Container Registry with AKS integration
- **Install_Kaito** - KAITO operator installation on AKS
- **Deploy_MCP_Servers** - MCP server infrastructure and networking
- **Configure_Monitoring** - Azure Monitor and Log Analytics integration
- **Network_Policies** - Advanced networking and security policies

## Relationship to Bash Guides

The Terraform configurations in this directory complement rather than replace
the bash-based executable documents in `docs/*.md`. Both approaches are
maintained:

- **Bash guides** - Interactive learning, exploration, one-off deployments
- **Terraform guides** - Production infrastructure, team collaboration, IaC practices

Where possible, bash guides and Terraform configurations are kept in sync to
ensure both methods produce equivalent infrastructure.

## Configuration Dependencies

Some Terraform configurations depend on others:

```
Create_Resource_Group (foundation)
    └── Create_AKS (depends on RG)
        └── Future: Install_Kaito, Deploy_ACR, etc.
```

Always complete prerequisite configurations before dependent ones.

## License

This infrastructure code follows the same license as the parent MCPaaS project.
