# Terraform RoboShop Component

**Role: Module Developer**

A reusable Terraform module for provisioning an individual RoboShop microservice component (e.g. catalogue, cart, shipping, payment, user, frontend) on AWS. This repo defines the module only — it is not applied directly, but called once per component from a module-user repo, with the underlying VPC and security group already provisioned.

## What This Module Creates

- Compute resource(s) (e.g. EC2 instance or Auto Scaling Group) for a single RoboShop component
- Any supporting resources needed to run and expose that component (e.g. load balancer target group attachment, depending on configuration)

> Check `main.tf` for the exact resource set — update this section to reflect what's actually defined.

## File Structure

| File | Purpose |
|------|---------|
| `main.tf` | Core resource definitions for the component |
| `data.tf` | Data sources (e.g. AMI lookup, VPC/subnet/security group lookups) |
| `locals.tf` | Local values used to compute names, tags, or shared configuration |
| `variables.tf` | Input variable definitions |

## Usage

```hcl
module "catalogue" {
  source = "github.com/Naga-Sai-Prasanna/terraform-roboshop-component"

  project      = "roboshop"
  environment  = "dev"
  component    = "catalogue"
  vpc_id       = module.vpc.vpc_id
  subnet_id    = module.vpc.private_subnet_ids[0]
  sg_id        = module.sg.security_group_id
  # additional variables as defined in variables.tf
}
```

This module is designed to be called multiple times — once per RoboShop component — by varying the `component` (and related) input.

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `project` | The project name, used for naming and tagging resources | `string` | Yes |
| `environment` | The environment name (e.g. `dev`, `uat`, `qa`, `prod`) | `string` | Yes |
| `component` | The name of the RoboShop component being deployed (e.g. `catalogue`, `cart`) | `string` | Yes |
| `vpc_id` | The VPC ID to deploy into | `string` | Yes |
| `subnet_id` | The subnet ID to deploy into | `string` | Yes |
| `sg_id` | The security group ID to attach | `string` | Yes |

> Check `variables.tf` for the exact, complete list of inputs — update this table to match.

## Outputs

> No `outputs.tf` was listed for this module at the time of writing. If outputs exist (e.g. `instance_id`, `private_ip`), add an `outputs.tf` and document them here.

## How This Fits Into the Bigger Picture

This module sits on top of the networking layer — it depends on both the VPC and security group modules being applied first:

```
terraform-aws-vpc  ──┐
                      ├──>  terraform-roboshop-component  ──>  roboshop-infra-dev  (module user)
terraform-aws-sg   ──┘
```

- **[`terraform-aws-vpc`](https://github.com/Naga-Sai-Prasanna/terraform-aws-vpc)** — provides the `vpc_id` and subnet IDs this module deploys into.
- **[`terraform-aws-sg`](https://github.com/Naga-Sai-Prasanna/terraform-aws-sg)** — provides the security group this module attaches to each component.
- **[`roboshop-infra-dev`](https://github.com/Naga-Sai-Prasanna/roboshop-infra-dev)** — the module-user repo. It calls this module once per RoboShop service (catalogue, cart, shipping, payment, etc.) after the VPC and SG modules have been applied, corresponding to its `60-catalogue` and `90-components` steps.

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.x |
| AWS Provider | >= 5.x |
