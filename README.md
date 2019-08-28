Terraform deployment with Azure DevOps, leveraging Azure pipelines in [YAML](http://aka.ms/yaml) with [Environment](https://docs.microsoft.com/azure/devops/pipelines/yaml-schema?view=azure-devops&tabs=schema#environment) and [Checks](https://docs.microsoft.com/azure/devops/pipelines/process/checks?view=azure-devops).

In Azure DevOps:
- to be able to leverage the Multi-stage pipelines Preview feature, [you need to turn it on](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/stages?view=azure-devops&tabs=yaml).
- to be able to install a specific version of Terraform on the agent, [install this Marketplace task](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks)

Further considerations:
- tf-state
- Illustrate the workflow with a diagram
- Leverage the Azure DevOps CLI to create pipeline et variables instead of using the UI
- Use Azure Key Vault to store secrets to be used by Azure pipelines
- In `terraform apply` reuse the output of `terraform plan`
- Add a `Production` stage by cloning the existing `Development` stage

Resources:
- [Running Terraform in Automation
](https://learn.hashicorp.com/terraform/development/running-terraform-in-automation)
