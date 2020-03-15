| phase | Status |
|--------|--------|
| prepare |[![Build Status](https://dev.azure.com/mabenoit-ms/MyOwnBacklog/_apis/build/status/azure-devops-terraform?branchName=master&stageName=prepare)](https://dev.azure.com/mabenoit-ms/MyOwnBacklog/_build/latest?definitionId=113&branchName=master)|
| plan dev |[![Build Status](https://dev.azure.com/mabenoit-ms/MyOwnBacklog/_apis/build/status/azure-devops-terraform?branchName=master&stageName=plan%20dev)](https://dev.azure.com/mabenoit-ms/MyOwnBacklog/_build/latest?definitionId=113&branchName=master)|
| apply dev |[![Build Status](https://dev.azure.com/mabenoit-ms/MyOwnBacklog/_apis/build/status/azure-devops-terraform?branchName=master&stageName=apply%20dev)](https://dev.azure.com/mabenoit-ms/MyOwnBacklog/_build/latest?definitionId=113&branchName=master)|
| plan prod |[![Build Status](https://dev.azure.com/mabenoit-ms/MyOwnBacklog/_apis/build/status/azure-devops-terraform?branchName=master&stageName=plan%20prod)](https://dev.azure.com/mabenoit-ms/MyOwnBacklog/_build/latest?definitionId=113&branchName=master)|
| apply prod |[![Build Status](https://dev.azure.com/mabenoit-ms/MyOwnBacklog/_apis/build/status/azure-devops-terraform?branchName=master&stageName=apply%20prod)](https://dev.azure.com/mabenoit-ms/MyOwnBacklog/_build/latest?definitionId=113&branchName=master)|

Terraform deployment with Azure DevOps, leveraging Azure pipelines in [YAML](http://aka.ms/yaml) with [Environment](https://docs.microsoft.com/azure/devops/pipelines/yaml-schema#environment) and [Checks](https://docs.microsoft.com/azure/devops/pipelines/process/checks).

![Azure pipeline](/azure-pipeline.png)

# Setup

## Setup Azure Storage for TF state

```
#!/bin/bash

environment=dev
TFSTATE_RESOURCE_GROUP_NAME=tfstate-$environment
TFSTATE_STORAGE_ACCOUNT_NAME=tfstate$RANDOM$environment
TFSTATE_BLOB_CONTAINER_NAME=tfstate-$environment

az group create -n $TFSTATE_RESOURCE_GROUP_NAME -l eastus
az storage account create -g $TFSTATE_RESOURCE_GROUP_NAME -n $TFSTATE_STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob
TFSTATE_STORAGE_ACCOUNT_KEY=$(az storage account keys list -g $TFSTATE_RESOURCE_GROUP_NAME --account-name $TFSTATE_STORAGE_ACCOUNT_NAME --query [0].value -o tsv)
az storage container create -n $TFSTATE_BLOB_CONTAINER_NAME --account-name $TFSTATE_STORAGE_ACCOUNT_NAME --account-key $TFSTATE_STORAGE_ACCOUNT_KEY

az group lock create --lock-type CanNotDelete -n CanNotDelete -g $TFSTATE_RESOURCE_GROUP_NAME
```

> Note: You could repeat this setup above per `environment`: QA, PROD, etc. That's a best practice to leverage different resources per environment, having more granular RBAC controls, etc.

## Setup Terraform access to Azure

When Terraform will deploy your Azure resources,it will need the appropriate rights to talk to Azure and perform such actions, [this tutorial](https://docs.microsoft.com/azure/virtual-machines/linux/terraform-install-configure) provides the details of this configuration you need to do. Below are the commands extracted from there to be able to reuse the different values necessary for further setups.

```
TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

environment=dev
spName=tf-sp-$environment
TF_SP_SECRET=$(az ad sp create-for-rbac -n $spName --role Contributor --query password -o tsv)
TF_SP_ID=$(az ad sp show --id http://$spName --query appId -o tsv)
```

> Note: You could repeat this setup above per `environment`: QA, PROD, etc. That's a best practice to leverage different resources per environment, having more granular RBAC controls, etc.

## Setup Azure DevOps

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

#Once the pipeline is created we need to configure its associated variables, by creating 3 different Variables Groups:
environment=dev
az pipelines variable-group create \
    --name tf-sp-group-$environment \
    --authorize true \
    --variables clientId=$TF_SP_ID clientSecret=$TF_SP_SECRET tenantId=$TENANT_ID subscriptionId=$SUBSCRIPTION_ID
az pipelines variable-group create \
    --name tf-state-group-$environment \
    --authorize true \
    --variables tfStateStorageAccountAccessKey=$TFSTATE_STORAGE_ACCOUNT_KEY tfStateStorageAccountName=$TFSTATE_STORAGE_ACCOUNT_NAME tfStateStorageContainerName=$TFSTATE_BLOB_CONTAINER_NAME
az pipelines variable-group create \
    --name tf-deployment-group-$environment \
    --authorize true \
    --variables location=<your-location-value> resourceGroupName=<your-resource-group-name-value>

#Let's run our first build!
az pipelines run \
    --name $BUILD_NAME \
    --open

#You may want to open this pipeline definition via the UI to track it
az pipelines show \
    --name $BUILD_NAME \
    --open
```

> Note: You could repeat this Variable Groups setup above per `environment`: QA, PROD, etc.

Optionaly, you could pause this pipeline by adding a manual approval step on the Environment by setting up a [Check Approval](https://docs.microsoft.com/azure/devops/pipelines/process/checks#approvals). This manual approval is right after `terraform plan` and right before `terraform apply`, a good way to make sure everything will be deployed as expected.

## Optional - Protect your Terraform State files with Private Endpoints for Azure Storage

Like illustrated in my blog article [Protect your Terraform State files with Private Endpoints for Azure Storage](https://alwaysupalwayson.blogspot.com/2020/03/protect-your-terraform-state-files-with.html) by running the commands below you will be able to leverage Azure Private Endpoint:
```
vnetName<your-vnet-name>
subnetName=<your-subnet-name>
privateEndpointName=<your-private-endpoint-name>
storageAccountId=$(az storage account show -g $TFSTATE_RESOURCE_GROUP_NAME -n $TFSTATE_STORAGE_ACCOUNT_NAME --query id -o tsv)
az network vnet subnet update -n $subnetName -g $TFSTATE_RESOURCE_GROUP_NAME --vnet-name $vnetName --disable-private-endpoint-network-policies true
az network private-endpoint create \
    -n $privateEndpointName \
    -g $TFSTATE_RESOURCE_GROUP_NAME \
    --vnet-name $vnetName  \
    --subnet $subnetName \
    --private-connection-resource-id $storageAccountId \
    --group-id blob \
    --connection-name $privateEndpointName
az storage account update \
    -g $TFSTATE_RESOURCE_GROUP_NAME \
    -n $storageName \
    --default-action Deny
zoneName="privatelink.blob.core.windows.net"
az network private-dns zone create \
    -g $TFSTATE_RESOURCE_GROUP_NAME \
    -n $zoneName
az network private-dns link vnet create \
    -g $TFSTATE_RESOURCE_GROUP_NAME \
    --zone-name $zoneName \
    -n $privateDnsName \
    --virtual-network $vnetName \
    --registration-enabled false
networkInterfaceId=$(az network private-endpoint show \
    -n $privateEndpointName \
    -g $TFSTATE_RESOURCE_GROUP_NAME \
    --query 'networkInterfaces[0].id' \
    -o tsv)
privateIpAddress=$(az resource show \
    --ids $networkInterfaceId \
    --api-version 2019-04-01 \
    --query properties.ipConfigurations[0].properties.privateIPAddress \
    -o tsv)
az network private-dns record-set a create \
    -n $TFSTATE_STORAGE_ACCOUNT_NAME 
    --zone-name $zoneName 
    -g $TFSTATE_RESOURCE_GROUP_NAME
az network private-dns record-set a add-record \
    --record-set-name $TFSTATE_STORAGE_ACCOUNT_NAME \
    --zone-name $zoneName \
    -g $TFSTATE_RESOURCE_GROUP_NAME \
    -a $privateIpAddress
```

Furthermore, you will have to have your own Azure Pipeline agent, in my case I'm hosting it on AKS, here are the setup you will need to have to link your AKS's VNET to your TFState's VNET:
```
aksResourceGroupName=<your-aks-rg-name>
aksVnetName=<your-aks-vnet-name>
vNet1Id=$(az network vnet show \
    -g $TFSTATE_RESOURCE_GROUP_NAME \
    -n $vnetName \
    --query id --out tsv)
vNet2Id=$(az network vnet show \
    -g $aksResourceGroupName \
    -n $aksVnetName \
    --query id --out tsv)
az network vnet peering create \
    -n tfstate-aks \
    -g $rg \
    --vnet-name $vnetName \
    --remote-vnet $vNet2Id \
    --allow-vnet-access
az network vnet peering create \
    -n aks-tfstate \
    -g $aksResourceGroupName \
    --vnet-name $aksVnetName \
    --remote-vnet $vNet1Id \
    --allow-vnet-access
az network private-dns link vnet create \
    -g $rg \
    --zone-name $zoneName \
    -n $privateDnsName \
    --virtual-network $aksVnetName \
    --registration-enabled false
```

# Further considerations

- Use Azure Key Vault to store secrets to be used by Azure pipelines, you could easily [leverage Azure KeyVault from Variable Groups](https://docs.microsoft.com/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=yaml#link-secrets-from-an-azure-key-vault)
- You may want to add more Azure services to deploy in the [tf](/tf) folder ;)

# Resources

- [Terraform on Azure](https://docs.microsoft.com/azure/terraform)
- [Running Terraform in Automation
](https://learn.hashicorp.com/terraform/development/running-terraform-in-automation)
- [Cloud Native Azure Infrastructure Deployment Using Terraform](https://www.hashicorp.com/resources/cloud-native-azure-infrastructure-deployment-using-terraform)
- [Microsoft Learn - Provision infrastructure in Azure Pipelines](https://docs.microsoft.com/learn/modules/provision-infrastructure-azure-pipelines/)
- [Find out more about Terraform on Azure](https://cloudblogs.microsoft.com/opensource/tag/terraform)
