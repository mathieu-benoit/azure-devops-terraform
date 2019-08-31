Terraform deployment with Azure DevOps, leveraging Azure pipelines in [YAML](http://aka.ms/yaml) with [Environment](https://docs.microsoft.com/azure/devops/pipelines/yaml-schema#environment) and [Checks](https://docs.microsoft.com/azure/devops/pipelines/process/checks).

![Azure pipeline](/azure-pipeline.png)

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
- To be able to leverage the Multi-stage pipelines Preview feature, [you need to turn it on](https://docs.microsoft.com/azure/devops/pipelines/process/stages).
- To be able to install a specific version of Terraform on the agent, [install this Marketplace task](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks)

To setup Azure pipelines in Azure DevOps we will use the Azure DevOps CLI instead of the UI. For the setup and to login accordingly to your Azure DevOps organization and project, you will need to follow the instructions [here](https://docs.microsoft.com/azure/devops/cli/get-started?view=azure-devops).

Now you will be able to run the bash commands below:
```
BUILD_NAME=<your-build-name>
GITHUB_URL=https://github.com/mathieu-benoit/azure-devops-terraform

#If your source code is in GitHub, you may want to create by CLI your GitHub service endpoint (otherwise via the UI), you will be asked for your GitHub access token.
SERVICE_ENDPOINT_NAME=azure-devops-terraform
az devops service-endpoint github create \
        --name $SERVICE_ENDPOINT_NAME \
        --github-url $GITHUB_URL

az pipelines create \
    --name $BUILD_NAME \
    --repository $GITHUB_URL \
    --branch master  \
    --yml-path azure-pipeline.yml \
    --service-connection $SERVICE_ENDPOINT_NAME
    --skip-first-run

#Once the pipeline created we need to configure its associated variables
az pipelines variable create \
    --pipeline-name $BUILD_NAME \
    --name location \
    --value <your-location>
az pipelines variable create \
    --pipeline-name $BUILD_NAME \
    --name resourceGroupName \
    --value <your-resource-group-name>
az pipelines variable create \
    --pipeline-name $BUILD_NAME \
    --name location \
    --value eastus

#Let's run our first build!
az pipelines run 

#You may want to open this pipeline definition via the UI to track him
az pipelines show \
    --name $BUILD_NAME \
    --open
```

Optionaly, you could pause this pipeline by adding a manual approval step on the Environment by setting up a [Check Approval](https://docs.microsoft.com/azure/devops/pipelines/process/checks#approvals). Like defining in my [azure-pipeline.yml](azure-pipeline.yml) file, this manual approval is right after `terraform plan` and right before `terraform apply`, a good way to make sure everything will be deployed as expected.

# Further considerations

- Leverage the Azure DevOps CLI to create pipeline et variables instead of using the UI
- Use Azure Key Vault to store secrets to be used by Azure pipelines
- In `terraform apply` reuse the output of `terraform plan`
- Add a `Production` stage by cloning the existing `Development` stage
- You may want to add more Azure services to deploy in the [tf](/tf) folder ;)

# Resources

- [Terraform on Azure](https://docs.microsoft.com/azure/terraform)
- [Running Terraform in Automation
](https://learn.hashicorp.com/terraform/development/running-terraform-in-automation)
- [Find out more about Terraform on Azure](https://cloudblogs.microsoft.com/opensource/tag/terraform)
