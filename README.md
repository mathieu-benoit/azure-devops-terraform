Terraform deployment with Azure DevOps, leveraging Azure pipelines in [YAML](http://aka.ms/yaml) with [Environment](https://docs.microsoft.com/azure/devops/pipelines/yaml-schema?view=azure-devops&tabs=schema#environment) and [Checks](https://docs.microsoft.com/azure/devops/pipelines/process/checks?view=azure-devops).

# Setup

## Azure Storage for TF state

```
#!/bin/bash

TFSTATE_RESOURCE_GROUP_NAME=tfstate
TFSTATE_STORAGE_ACCOUNT_NAME=tfstate$RANDOM
TFSTATE_BLOB_CONTAINER_NAME=tfstate

az group create -n $TFSTATE_RESOURCE_GROUP_NAME -l eastus
az storage account create -g $TFSTATE_RESOURCE_GROUP_NAME -n $TFSTATE_STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob
ACCOUNT_KEY=$(az storage account keys list -g $TFSTATE_RESOURCE_GROUP_NAME --account-name $TFSTATE_STORAGE_ACCOUNT_NAME --query [0].value -o tsv)
az storage container create -n $TFSTATE_BLOB_CONTAINER_NAME --account-name $TFSTATE_STORAGE_ACCOUNT_NAME --account-key $ACCOUNT_KEY

echo "storage_account_name: $TFSTATE_STORAGE_ACCOUNT_NAME"
echo "container_name: $TFSTATE_BLOB_CONTAINER_NAME"
echo "access_key: $ACCOUNT_KEY"
```

Note: you may want to either reuse this setup for all your environments (Development, Production, etc.) or create one per environment.

## Azure DevOps

Prerequisites:
- To be able to leverage the Multi-stage pipelines Preview feature, [you need to turn it on](https://docs.microsoft.com/azure/devops/pipelines/process/stages?view=azure-devops&tabs=yaml).
- to be able to install a specific version of Terraform on the agent, [install this Marketplace task](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks)

TODO

# Further considerations

- Leverage the Azure DevOps CLI to create pipeline et variables instead of using the UI
- Use Azure Key Vault to store secrets to be used by Azure pipelines
- In `terraform apply` reuse the output of `terraform plan`
- Add a `Production` stage by cloning the existing `Development` stage
- You may want to add more Azure services to deploy in the [tf](/tf) folder ;)

# Resources

- [Terraform on Azure](https://docs.microsoft.com/azure/terraform/)
- [Running Terraform in Automation
](https://learn.hashicorp.com/terraform/development/running-terraform-in-automation)
