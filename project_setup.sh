#!/bin/bash

#uncomment the line below to connect to azure & login from outside of Cloud Shell
#az login

############################################
############## VARIABLES ###################
############################################
export SSL_EMAIL_ADDRESS="$(az account show --query user.name --output tsv)"
export NETWORK_PREFIX="$(($RANDOM % 253 + 1))"
export MY_RESOURCE_GROUP_NAME="main_resource_group"
export GLOBAL_RESOURCE_GROUP="globalRGroup"
export REGION="canadacentral"
export DB_KEY_VAULT="epsilonDBKV$(($RANDOM % 10000 + 1))"
export MY_AKS_CLUSTER_NAME="epsilonAKSCluster"
export MY_PUBLIC_IP_NAME="epsilonPublicIP"
export MY_DNS_LABEL="epsilondnslabel"
export AKS_DNS_LABEL="epsilonaksdnslabel"

export MY_VNET_NAME="epsilonVNet"
export AKS_SUBNET_NAME="AKSSubnet"
export AKS_NSG_NAME="AKSSubnetNSG"
export DB_SUBNET_NAME="DBSubnet"
export DB_NSG_NAME="DBSubnetNSG"
export KV_SUBNET_NAME="KVSubnet"
export KV_NSG_NAME="KVSubnetNSG"
export MY_VNET_PREFIX="10.$NETWORK_PREFIX.0.0/16"
export AKS_SUBNET_PREFIX="10.$NETWORK_PREFIX.1.0/24"
export DB_SUBNET_PREFIX="10.$NETWORK_PREFIX.2.0/24"
export KV_SUBNET_PREFIX="10.$NETWORK_PREFIX.3.0/24"

export MY_WP_ADMIN_PW="g8tr_p#dw9RDo"
export MY_WP_ADMIN_USER="epsilon"
export FQDN="$MY_DNS_LABEL.export REGION.cloudapp.azure.com"
export MY_MYSQL_SERVER_NAME="mysqlwordpsrvr"
export MY_MYSQL_DB_NAME="wordpressdb"
export MY_MYSQL_ADMIN_USERNAME="developer"
export MY_MYSQL_ADMIN_PW="g8tr_p#dw9RDo"
export MY_MYSQL_HOSTNAME="$MY_MYSQL_SERVER_NAME.mysql.database.azure.com"
export ACR_NAME="epsilonacr"
export MY_NAMESPACE="epsilon-ns13"
export GROUP_ID="$(az ad group show --group "Epsilon" --query "id" --output tsv)"
export SUBSCRIPTIONS_ID="$(az account show --query id --output tsv)"
export MSYS_NO_PATHCONV=1
export PRIMARY_ORIGIN_NAME="primaryOrigin"
export DOCKER_HUB_IMAGE_NAME="djhlee5/project8:latest"
export PRIVATE_DNS_ZONE_NAME="privatelink.mysql.database.azure.com"
export IDENTITY_NAME="epsilon_id"
export DB_KEY_NAME="EpsilonDBKey"

export TRAFFIC_MANAGER_NAME="epsilonTM"
export TRAFFIC_MANAGER_UNIQUE_DNS_NAME="epsilonTMDNS$(($RANDOM % 10000 + 1))"

##################################################
############### SUBNET AND NSGS ##################
##################################################

#create main resource group
az group create --name $MY_RESOURCE_GROUP_NAME --location $REGION

#create resource group for Traffic Manager
az group create --name $GLOBAL_RESOURCE_GROUP --location $REGION


#Set up Vnet
az network vnet create \
    --resource-group $MY_RESOURCE_GROUP_NAME \
    --location $REGION \
    --name $MY_VNET_NAME \
    --address-prefix $MY_VNET_PREFIX

# Create AKS Subnet-NSG
az network nsg create --resource-group $MY_RESOURCE_GROUP_NAME --name $AKS_NSG_NAME --location $REGION


# Create AKS Subnet
az network vnet subnet create \
  --name $AKS_SUBNET_NAME \
  --resource-group $MY_RESOURCE_GROUP_NAME \
  --vnet-name $MY_VNET_NAME \
  --address-prefixes $AKS_SUBNET_PREFIX \
  --network-security-group $AKS_NSG_NAME


# Create Database Subnet-NSG
az network nsg create --resource-group $MY_RESOURCE_GROUP_NAME --name $DB_NSG_NAME --location $REGION


# Create Database Subnet
az network vnet subnet create \
  --name $DB_SUBNET_NAME \
  --resource-group $MY_RESOURCE_GROUP_NAME \
  --vnet-name $MY_VNET_NAME \
  --address-prefixes $DB_SUBNET_PREFIX \
  --network-security-group $DB_NSG_NAME


# Create Key Vault Subnet-NSG
az network nsg create --resource-group $MY_RESOURCE_GROUP_NAME --name $KV_NSG_NAME --location $REGION


# Create Key Vault Subnet
az network vnet subnet create \
  --name $KV_SUBNET_NAME \
  --resource-group $MY_RESOURCE_GROUP_NAME \
  --vnet-name $MY_VNET_NAME \
  --address-prefixes $KV_SUBNET_PREFIX \
  --network-security-group $KV_NSG_NAME

############################################
############### NSG RULES ##################
############################################

az network nsg rule create \
  --resource-group $MY_RESOURCE_GROUP_NAME \
  --nsg-name $AKS_NSG_NAME \
  --name Allow_HTTP_To_AKS \
  --priority 300 \
  --direction Inbound \
  --destination-port-ranges 80 \
  --source-address-prefixes Internet \
  --access Allow

az network nsg rule create \
  --resource-group $MY_RESOURCE_GROUP_NAME \
  --nsg-name $DB_NSG_NAME \
  --name Allow_Traffic_From_AKS \
  --priority 100 \
  --direction Inbound \
  --protocol Tcp \
  --source-address-prefixes $AKS_SUBNET_PREFIX \
  --destination-address-prefixes $DB_SUBNET_PREFIX \
  --destination-port-ranges 3306 \
  --access Allow

az network nsg rule create \
  --resource-group $MY_RESOURCE_GROUP_NAME \
  --nsg-name $KV_NSG_NAME \
  --name Allow_Traffic_From_AKS \
  --priority 100 \
  --direction Inbound \
  --protocol Tcp \
  --source-address-prefixes $AKS_SUBNET_PREFIX \
  --destination-address-prefixes $KV_SUBNET_PREFIX \
  --destination-port-ranges 443 \
  --access Allow

############################################
############# DNS ZONE SETUP################
############################################

#Configure private DNS Zone
az network private-dns zone create --resource-group $MY_RESOURCE_GROUP_NAME \
   --name $PRIVATE_DNS_ZONE_NAME


##################################################
###### KEY VAULT AND ITS PRIVATE ENDPOINT ########
##################################################

#Set up key vault
az keyvault create -g $MY_RESOURCE_GROUP_NAME --administrators $GROUP_ID -n $DB_KEY_VAULT --location $REGION \
   --enable-rbac-authorization false --enable-purge-protection true

#Assign admin role to group
az role assignment create --assignee-object-id $GROUP_ID \
  --role "Key Vault Administrator" \
  --scope "subscriptions/$SUBSCRIPTIONS_ID/resourceGroups/$MY_RESOURCE_GROUP_NAME/providers/Microsoft.KeyVault/vaults/$DB_KEY_VAULT" 

#Create key in keyvault
export keyIdentifier=$(az keyvault key create --name $DB_KEY_NAME -p software --vault-name $DB_KEY_VAULT --query key.kid  --output tsv)

# create identity and save its principalId
export identityPrincipalId=$(az identity create -g $MY_RESOURCE_GROUP_NAME --name $IDENTITY_NAME --location $REGION --query principalId --output tsv)

# add testIdentity as an access policy with key permissions 'Wrap Key', 'Unwrap Key', 'Get' and 'List' inside testVault
az keyvault set-policy -g $MY_RESOURCE_GROUP_NAME \
  -n $DB_KEY_VAULT \
  --object-id $identityPrincipalId \
  --key-permissions wrapKey unwrapKey get list

#create private endpoint for key vault
az network private-endpoint create \
    --name KVPrivateEndpoint \
    --resource-group $MY_RESOURCE_GROUP_NAME \
    --vnet-name $MY_VNET_NAME  \
    --subnet $KV_SUBNET_NAME \
    --private-connection-resource-id $(az resource show -g $MY_RESOURCE_GROUP_NAME -n $DB_KEY_VAULT --resource-type "Microsoft.KeyVault/vaults" --query "id" -o tsv) \
    --group-id vault \
    --connection-name KVConnection \
    --location $REGION \
    --subscription $SUBSCRIPTIONS_ID


#Link private dns to existing Vnet, make the private accessible in public internet
az network private-dns link vnet create --resource-group $MY_RESOURCE_GROUP_NAME \
   --zone-name  $PRIVATE_DNS_ZONE_NAME \
   --name DNSLink \
   --virtual-network $MY_VNET_NAME \
   --registration-enabled false

export kvNetworkInterfaceId=$(az network private-endpoint show --name KVPrivateEndpoint --resource-group $MY_RESOURCE_GROUP_NAME --query 'networkInterfaces[0].id' -o tsv)
export private_ip_kv=$(az resource show --ids $kvNetworkInterfaceId --api-version 2019-04-01 --query 'properties.ipConfigurations[0].properties.privateIPAddress' -o tsv)

#add the record set as the name we set in key vault
az network private-dns record-set a create --name $DB_KEY_VAULT \
    --zone-name $PRIVATE_DNS_ZONE_NAME \
    --resource-group $MY_RESOURCE_GROUP_NAME

#add the private ip of aks cluster and link with key vault
az network private-dns record-set a add-record --record-set-name $DB_KEY_VAULT \
    --zone-name $PRIVATE_DNS_ZONE_NAME \
    -g $MY_RESOURCE_GROUP_NAME \
    -a $private_ip_kv

##################################################
####### DATABASE AND ITS PRIVATE ENDPOINT ########
##################################################

# create mysql server
az mysql flexible-server create \
    --admin-password $MY_MYSQL_ADMIN_PW \
    --admin-user $MY_MYSQL_ADMIN_USERNAME \
    --auto-scale-iops Disabled \
    --high-availability Disabled \
    --iops 360 \
    --location $REGION \
    --name $MY_MYSQL_SERVER_NAME \
    --database-name $MY_MYSQL_DB_NAME \
    --resource-group $MY_RESOURCE_GROUP_NAME \
    --sku-name Standard_B2s \
    --storage-auto-grow Disabled \
    --storage-size 20 \
    --key $keyIdentifier \
    --identity $IDENTITY_NAME \
    --tier Burstable \
    --version 8.0.21 \
    --yes -o JSON
    

#create private endpoint for az mysql
az network private-endpoint create \
    --name DBPrivateEndpoint \
    --resource-group $MY_RESOURCE_GROUP_NAME \
    --vnet-name $MY_VNET_NAME  \
    --subnet $DB_SUBNET_NAME \
    --private-connection-resource-id $(az resource show -g $MY_RESOURCE_GROUP_NAME -n $MY_MYSQL_SERVER_NAME --resource-type "Microsoft.DBforMySQL/flexibleServers" --query "id" -o tsv) \
    --group-id mysqlServer \
    --connection-name DBConnection \
    --location $REGION \
    --subscription $SUBSCRIPTIONS_ID

export dbNetworkInterfaceId=$(az network private-endpoint show --name DBPrivateEndpoint --resource-group $MY_RESOURCE_GROUP_NAME --query 'networkInterfaces[0].id' -o tsv)
export private_ip_db=$(az resource show --ids $dbNetworkInterfaceId --api-version 2019-04-01 --query 'properties.ipConfigurations[0].properties.privateIPAddress' -o tsv)

#add the record set as the name we set in db host
az network private-dns record-set a create --name $MY_MYSQL_SERVER_NAME \
    --zone-name $PRIVATE_DNS_ZONE_NAME \
    --resource-group $MY_RESOURCE_GROUP_NAME

#add the private ip of aks cluster and link with mysql server
az network private-dns record-set a add-record --record-set-name $MY_MYSQL_SERVER_NAME \
    --zone-name $PRIVATE_DNS_ZONE_NAME \
    -g $MY_RESOURCE_GROUP_NAME \
    -a $private_ip_db

az mysql flexible-server parameter set \
  --name require_secure_transport \
  --resource-group $MY_RESOURCE_GROUP_NAME \
  --server-name $MY_MYSQL_SERVER_NAME \
  --value OFF

##################################################
############## CONTAINER REGISTRY ################
##################################################

# Create Azure Container Registry
az acr create --resource-group $GLOBAL_RESOURCE_GROUP --name $ACR_NAME --sku Basic

# Import Docker image from Docker Hub to ACR
az acr import --name $ACR_NAME --source docker.io/$DOCKER_HUB_IMAGE_NAME --image $DOCKER_HUB_IMAGE_NAME --resource-group $GLOBAL_RESOURCE_GROUP


#################################################
################ AKS CREATION ###################
#################################################

# Register AKS Provider
az provider register --namespace Microsoft.ContainerService

#create aks cluster
az aks create \
    --resource-group $MY_RESOURCE_GROUP_NAME \
    --name $MY_AKS_CLUSTER_NAME \
    --auto-upgrade-channel stable \
    --enable-cluster-autoscaler \
    --location $REGION \
    --node-count 1 \
    --min-count 1 \
    --max-count 2 \
    --network-plugin azure \
    --network-policy azure \
    --enable-addons monitoring \
    --no-ssh-key \
    --node-vm-size Standard_DS2_v2 \
    --service-cidr 10.255.0.0/24 \
    --dns-service-ip 10.255.0.10 \
    --zones 1 2 3 \
    --enable-addons azure-keyvault-secrets-provider \
    --generate-ssh-keys \
    --attach-acr $ACR_NAME \
    --enable-managed-identity \
    --vnet-subnet-id "/subscriptions/$SUBSCRIPTIONS_ID/resourceGroups/$MY_RESOURCE_GROUP_NAME/providers/Microsoft.Network/virtualNetworks/$MY_VNET_NAME/subnets/$AKS_SUBNET_NAME"

#get AKS cluster credenials
az aks get-credentials --name $MY_AKS_CLUSTER_NAME --resource-group $MY_RESOURCE_GROUP_NAME

##################################################
############### CLUSTER SECRETS ##################
##################################################

# Create Kubernetes Secret for MySQL Credentials
kubectl create secret generic mysql-secret \
  --from-literal=username=$MY_MYSQL_ADMIN_USERNAME \
  --from-literal=password=$MY_MYSQL_ADMIN_PW


#get managed identity id from aks cluster
export aks_prinipal_id="$(az identity list -g MC_${MY_RESOURCE_GROUP_NAME}_${MY_AKS_CLUSTER_NAME}_${REGION} --query [0].principalId --output tsv)"

#set the key vault certificate officer to k8s cluster managed identity
az role assignment create --assignee-object-id $aks_prinipal_id \
  --role "Key Vault Certificates Officer" \
  --scope "subscriptions/$SUBSCRIPTIONS_ID/resourceGroups/$MY_RESOURCE_GROUP_NAME/providers/Microsoft.KeyVault/vaults/$DB_KEY_VAULT" 

#create the secret for k8s cluster
az keyvault secret set --vault-name $DB_KEY_VAULT --name AKSClusterSecret --value AKS_sample_secret


#create the access policy for connecting keyvault and k8s managed identiity
az keyvault set-policy -g $MY_RESOURCE_GROUP_NAME \
  -n $DB_KEY_VAULT \
  --object-id $aks_prinipal_id \
  --secret-permissions backup delete get list recover restore set

####################################################
############### DEPLOY TO CLUSTER ##################
####################################################

# Add the official stable repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update


# Install Helm ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
    --set controller.nodeSelector."kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.service.externalTrafficPolicy=Local \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"=$AKS_DNS_LABEL \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
    --wait --timeout 3m0s

echo "apiVersion: apps/v1
kind: Deployment
metadata:
  name: akswordpress-deployment
spec:
  selector:
    matchLabels:
      app: akswordpress
  template:
    metadata:
      labels:
        app: akswordpress
    spec:
      containers:
      - name: akswordpress
        image: ${ACR_NAME}.azurecr.io/${DOCKER_HUB_IMAGE_NAME}
        env:
        - name: WORDPRESS_DB_HOST
          value: ${MY_MYSQL_SERVER_NAME}.${PRIVATE_DNS_ZONE_NAME}
        - name: WORDPRESS_DB_NAME
          value: ${MY_MYSQL_DB_NAME}
        - name: WORDPRESS_DB_USER
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: username
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "256Mi"
            cpu: "500m"
          limits:
            memory: "512Mi"
            cpu: "1"
" > deployment.yaml

echo "apiVersion: v1
kind: Service
metadata:
  name: clustorip-svc
  labels: 
    app: akswordpress  #Has to be same what's labelled in deployment YAML
spec:
  type: ClusterIP 
  selector:
    app: akswordpress  #Has to be same what's labelled in deployment YAML
  ports: 
    - port: 80        #Service Port
      targetPort: 80     #Container Port defined in Deployment YAML
" > service.yaml

echo "apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-svc 
  annotations:
    kubernetes.io/ingress.class: "nginx"  # Ensures this annotation is correct
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: clustorip-svc
                port: 
                  number: 80
" > ingress.yaml

# Apply the Deployment, Service, and Ingress in Kubernetes
kubectl apply -f deployment.yaml

kubectl apply -f service.yaml

kubectl apply -f ingress.yaml

#############################################
############# TRAFFIC MANAGER ###############
#############################################

# Create a Traffic Manager profile.
az network traffic-manager profile create \
  --name $TRAFFIC_MANAGER_NAME \
  --resource-group $GLOBAL_RESOURCE_GROUP \
  --routing-method Priority \
  --unique-dns-name $TRAFFIC_MANAGER_UNIQUE_DNS_NAME

export aks_resource_id=$(az network public-ip list --query "[?dnsSettings.domainNameLabel=='$AKS_DNS_LABEL']" | jq -r '.[].id')

# Create a traffic manager endpoint for primary cluster
az network traffic-manager endpoint create \
  --name primaryEndpoint \
  --profile-name $TRAFFIC_MANAGER_NAME \
  --resource-group $GLOBAL_RESOURCE_GROUP \
  --type azureEndpoints \
  --priority 1 \
  --endpoint-status Enabled \
  --target-resource-id $aks_resource_id


##################################################
############### SECONDARY REGION #################
##################################################
export NETWORK_PREFIX_2="$(($RANDOM % 253 + 1))"
export REGION_2="centralus"
export DB_KEY_VAULT_2="epsilonDB2KV$(($RANDOM % 10000 + 1))"
export MY_AKS_CLUSTER_NAME_2="epsilonAKSCluster2"
export MY_PUBLIC_IP_NAME_2="epsilonPublicIP2"
export MY_DNS_LABEL_2="epsilondnslabel2"
export AKS_DNS_LABEL_2="epsilonaksdnslabel2"
export MY_RESOURCE_GROUP_NAME_2="second_resource_group"

export MY_VNET_NAME_2="epsilonVNet2"
export AKS_SUBNET_NAME_2="AKSSubnet2"
export AKS_NSG_NAME_2="AKSSubnetNSG2"
export DB_SUBNET_NAME_2="DBSubnet2"
export DB_NSG_NAME_2="DBSubnetNSG2"
export KV_SUBNET_NAME_2="KVSubnet2"
export KV_NSG_NAME_2="KVSubnetNSG2"
export MY_VNET_PREFIX_2="10.$NETWORK_PREFIX_2.0.0/16"
export AKS_SUBNET_PREFIX_2="10.$NETWORK_PREFIX_2.1.0/24"
export DB_SUBNET_PREFIX_2="10.$NETWORK_PREFIX_2.2.0/24"
export KV_SUBNET_PREFIX_2="10.$NETWORK_PREFIX_2.3.0/24"

export FQDN_2="$MY_DNS_LABEL_2.export REGION.cloudapp.azure.com"
export MY_MYSQL_SERVER_NAME_2="mysqlwordpsrvr2"
export MY_MYSQL_DB_NAME_2="wordpressdb2"
export MY_MYSQL_HOSTNAME_2="$MY_MYSQL_SERVER_NAME_2.mysql.database.azure.com"
export MY_NAMESPACE_2="epsilon-ns31"
export ORIGIN_NAME_2="secondaryOrigin"
export PRIVATE_DNS_ZONE_NAME_2="privatelink2.mysql.database.azure.com"
export IDENTITY_NAME_2="epsilon_id_2"
export DB_KEY_NAME_2="EpsilonDBKey2"


#create main resource group
az group create --name $MY_RESOURCE_GROUP_NAME_2 --location $REGION_2

#Set up Vnet
az network vnet create \
    --resource-group $MY_RESOURCE_GROUP_NAME_2 \
    --location $REGION_2 \
    --name $MY_VNET_NAME_2 \
    --address-prefix $MY_VNET_PREFIX_2

# Create AKS Subnet-NSG
az network nsg create --resource-group $MY_RESOURCE_GROUP_NAME_2 --name $AKS_NSG_NAME_2 --location $REGION_2


# Create AKS Subnet
az network vnet subnet create \
  --name $AKS_SUBNET_NAME_2 \
  --resource-group $MY_RESOURCE_GROUP_NAME_2 \
  --vnet-name $MY_VNET_NAME_2 \
  --address-prefixes $AKS_SUBNET_PREFIX_2 \
  --network-security-group $AKS_NSG_NAME_2


# Create Database Subnet-NSG
az network nsg create --resource-group $MY_RESOURCE_GROUP_NAME_2 --name $DB_NSG_NAME_2 --location $REGION_2


# Create Database Subnet
az network vnet subnet create \
  --name $DB_SUBNET_NAME_2 \
  --resource-group $MY_RESOURCE_GROUP_NAME_2 \
  --vnet-name $MY_VNET_NAME_2 \
  --address-prefixes $DB_SUBNET_PREFIX_2 \
  --network-security-group $DB_NSG_NAME_2


# Create Key Vault Subnet-NSG
az network nsg create --resource-group $MY_RESOURCE_GROUP_NAME_2 --name $KV_NSG_NAME_2 --location $REGION_2


# Create Key Vault Subnet
az network vnet subnet create \
  --name $KV_SUBNET_NAME_2 \
  --resource-group $MY_RESOURCE_GROUP_NAME_2 \
  --vnet-name $MY_VNET_NAME_2 \
  --address-prefixes $KV_SUBNET_PREFIX_2 \
  --network-security-group $KV_NSG_NAME_2

############################################
############### NSG RULES ##################
############################################

az network nsg rule create \
  --resource-group $MY_RESOURCE_GROUP_NAME_2 \
  --nsg-name $AKS_NSG_NAME_2 \
  --name Allow_HTTP_To_AKS \
  --priority 300 \
  --direction Inbound \
  --destination-port-ranges 80 \
  --source-address-prefixes Internet \
  --access Allow

az network nsg rule create \
  --resource-group $MY_RESOURCE_GROUP_NAME_2 \
  --nsg-name $DB_NSG_NAME_2 \
  --name Allow_Traffic_From_AKS \
  --priority 100 \
  --direction Inbound \
  --protocol Tcp \
  --source-address-prefixes $AKS_SUBNET_PREFIX_2 \
  --destination-address-prefixes $DB_SUBNET_PREFIX_2 \
  --destination-port-ranges 3306 \
  --access Allow

az network nsg rule create \
  --resource-group $MY_RESOURCE_GROUP_NAME_2 \
  --nsg-name $KV_NSG_NAME_2 \
  --name Allow_Traffic_From_AKS \
  --priority 100 \
  --direction Inbound \
  --protocol Tcp \
  --source-address-prefixes $AKS_SUBNET_PREFIX_2 \
  --destination-address-prefixes $KV_SUBNET_PREFIX_2 \
  --destination-port-ranges 443 \
  --access Allow

############################################
############# DNS ZONE SETUP################
############################################

#Configure private DNS Zone
az network private-dns zone create --resource-group $MY_RESOURCE_GROUP_NAME_2 \
   --name $PRIVATE_DNS_ZONE_NAME_2


##################################################
###### KEY VAULT AND ITS PRIVATE ENDPOINT ########
##################################################

#Set up key vault
az keyvault create -g $MY_RESOURCE_GROUP_NAME_2 --administrators $GROUP_ID -n $DB_KEY_VAULT_2 --location $REGION_2 \
   --enable-rbac-authorization false --enable-purge-protection true

#Assign admin role to group
az role assignment create --assignee-object-id $GROUP_ID \
  --role "Key Vault Administrator" \
  --scope "subscriptions/$SUBSCRIPTIONS_ID/resourceGroups/$MY_RESOURCE_GROUP_NAME_2/providers/Microsoft.KeyVault/vaults/$DB_KEY_VAULT_2" 

#Create key in keyvault
export keyIdentifier_2=$(az keyvault key create --name $DB_KEY_NAME_2 -p software --vault-name $DB_KEY_VAULT_2 --query key.kid  --output tsv)

# create identity and save its principalId
export identityPrincipalId_2=$(az identity create -g $MY_RESOURCE_GROUP_NAME_2 --name $IDENTITY_NAME_2 --location $REGION_2 --query principalId --output tsv)

# add testIdentity as an access policy with key permissions 'Wrap Key', 'Unwrap Key', 'Get' and 'List' inside testVault
az keyvault set-policy -g $MY_RESOURCE_GROUP_NAME_2 \
  -n $DB_KEY_VAULT_2 \
  --object-id $identityPrincipalId_2 \
  --key-permissions wrapKey unwrapKey get list

#create private endpoint for key vault
az network private-endpoint create \
    --name KVPrivateEndpoint2 \
    --resource-group $MY_RESOURCE_GROUP_NAME_2 \
    --vnet-name $MY_VNET_NAME_2  \
    --subnet $KV_SUBNET_NAME_2 \
    --private-connection-resource-id $(az resource show -g $MY_RESOURCE_GROUP_NAME_2 -n $DB_KEY_VAULT_2 --resource-type "Microsoft.KeyVault/vaults" --query "id" -o tsv) \
    --group-id vault \
    --connection-name KVConnection2 \
    --location $REGION_2 \
    --subscription $SUBSCRIPTIONS_ID


#Link private dns to existing Vnet, make the private accessible in public internet
az network private-dns link vnet create --resource-group $MY_RESOURCE_GROUP_NAME_2 \
   --zone-name  $PRIVATE_DNS_ZONE_NAME_2 \
   --name DNSLink2 \
   --virtual-network $MY_VNET_NAME_2 \
   --registration-enabled false

export kvNetworkInterfaceId_2=$(az network private-endpoint show --name KVPrivateEndpoint2 --resource-group $MY_RESOURCE_GROUP_NAME_2 --query 'networkInterfaces[0].id' -o tsv)
export private_ip_kv_2=$(az resource show --ids $kvNetworkInterfaceId_2 --api-version 2019-04-01 --query 'properties.ipConfigurations[0].properties.privateIPAddress' -o tsv)

#add the record set as the name we set in key vault
az network private-dns record-set a create --name $DB_KEY_VAULT_2 \
    --zone-name $PRIVATE_DNS_ZONE_NAME_2 \
    --resource-group $MY_RESOURCE_GROUP_NAME_2

#add the private ip of aks cluster and link with key vault
az network private-dns record-set a add-record --record-set-name $DB_KEY_VAULT_2 \
    --zone-name $PRIVATE_DNS_ZONE_NAME_2 \
    -g $MY_RESOURCE_GROUP_NAME_2 \
    -a $private_ip_kv_2

##################################################
####### DATABASE AND ITS PRIVATE ENDPOINT ########
##################################################

# create mysql server
az mysql flexible-server create \
    --admin-password $MY_MYSQL_ADMIN_PW \
    --admin-user $MY_MYSQL_ADMIN_USERNAME \
    --auto-scale-iops Disabled \
    --high-availability Disabled \
    --iops 360 \
    --location $REGION_2 \
    --name $MY_MYSQL_SERVER_NAME_2 \
    --database-name $MY_MYSQL_DB_NAME_2 \
    --resource-group $MY_RESOURCE_GROUP_NAME_2 \
    --sku-name Standard_B2s \
    --storage-auto-grow Disabled \
    --storage-size 20 \
    --key $keyIdentifier_2 \
    --identity $IDENTITY_NAME_2 \
    --tier Burstable \
    --version 8.0.21 \
    --yes -o JSON
    

#create private endpoint for az mysql
az network private-endpoint create \
    --name DBPrivateEndpoint2 \
    --resource-group $MY_RESOURCE_GROUP_NAME_2 \
    --vnet-name $MY_VNET_NAME_2  \
    --subnet $DB_SUBNET_NAME_2 \
    --private-connection-resource-id $(az resource show -g $MY_RESOURCE_GROUP_NAME_2 -n $MY_MYSQL_SERVER_NAME_2 --resource-type "Microsoft.DBforMySQL/flexibleServers" --query "id" -o tsv) \
    --group-id mysqlServer2 \
    --connection-name DBConnection2 \
    --location $REGION_2 \
    --subscription $SUBSCRIPTIONS_ID

export dbNetworkInterfaceId_2=$(az network private-endpoint show --name DBPrivateEndpoint2 --resource-group $MY_RESOURCE_GROUP_NAME_2 --query 'networkInterfaces[0].id' -o tsv)
export private_ip_db_2=$(az resource show --ids $dbNetworkInterfaceId_2 --api-version 2019-04-01 --query 'properties.ipConfigurations[0].properties.privateIPAddress' -o tsv)

#add the record set as the name we set in db host
az network private-dns record-set a create --name $MY_MYSQL_SERVER_NAME_2 \
    --zone-name $PRIVATE_DNS_ZONE_NAME_2 \
    --resource-group $MY_RESOURCE_GROUP_NAME_2

#add the private ip of aks cluster and link with mysql server
az network private-dns record-set a add-record --record-set-name $MY_MYSQL_SERVER_NAME_2 \
    --zone-name $PRIVATE_DNS_ZONE_NAME_2 \
    -g $MY_RESOURCE_GROUP_NAME_2 \
    -a $private_ip_db_2

az mysql flexible-server parameter set \
  --name require_secure_transport \
  --resource-group $MY_RESOURCE_GROUP_NAME_2 \
  --server-name $MY_MYSQL_SERVER_NAME_2 \
  --value OFF

#################################################
################ AKS CREATION ###################
#################################################

# Register AKS Provider
az provider register --namespace Microsoft.ContainerService

#create aks cluster
az aks create \
    --resource-group $MY_RESOURCE_GROUP_NAME_2 \
    --name $MY_AKS_CLUSTER_NAME_2 \
    --auto-upgrade-channel stable \
    --enable-cluster-autoscaler \
    --location $REGION_2 \
    --node-count 1 \
    --min-count 1 \
    --max-count 2 \
    --network-plugin azure \
    --network-policy azure \
    --enable-addons monitoring \
    --no-ssh-key \
    --node-vm-size Standard_DS2_v2 \
    --service-cidr 10.255.0.0/24 \
    --dns-service-ip 10.255.0.10 \
    --zones 1 2 3 \
    --enable-addons azure-keyvault-secrets-provider \
    --generate-ssh-keys \
    --attach-acr $ACR_NAME \
    --enable-managed-identity \
    --vnet-subnet-id "/subscriptions/$SUBSCRIPTIONS_ID/resourceGroups/$MY_RESOURCE_GROUP_NAME_2/providers/Microsoft.Network/virtualNetworks/$MY_VNET_NAME_2/subnets/$AKS_SUBNET_NAME_2"

#get AKS cluster credenials
az aks get-credentials --name $MY_AKS_CLUSTER_NAME_2 --resource-group $MY_RESOURCE_GROUP_NAME_2

##################################################
############### CLUSTER SECRETS ##################
##################################################

# Create Kubernetes Secret for MySQL Credentials
kubectl create secret generic mysql-secret \
  --from-literal=username=$MY_MYSQL_ADMIN_USERNAME \
  --from-literal=password=$MY_MYSQL_ADMIN_PW


#get managed identity id from aks cluster
export aks_prinipal_id_2="$(az identity list -g MC_${MY_RESOURCE_GROUP_NAME_2}_${MY_AKS_CLUSTER_NAME_2}_${REGION_2} --query [0].principalId --output tsv)"

#set the key vault certificate officer to k8s cluster managed identity
az role assignment create --assignee-object-id $aks_prinipal_id_2 \
  --role "Key Vault Certificates Officer" \
  --scope "subscriptions/$SUBSCRIPTIONS_ID_2/resourceGroups/$MY_RESOURCE_GROUP_NAME_2/providers/Microsoft.KeyVault/vaults/$DB_KEY_VAULT_2" 

#create the secret for k8s cluster
az keyvault secret set --vault-name $DB_KEY_VAULT_2 --name AKSClusterSecret --value AKS_sample_secret


#create the access policy for connecting keyvault and k8s managed identiity
az keyvault set-policy -g $MY_RESOURCE_GROUP_NAME_2 \
  -n $DB_KEY_VAULT_2 \
  --object-id $aks_prinipal_id_2 \
  --secret-permissions backup delete get list recover restore set

####################################################
############### DEPLOY TO CLUSTER ##################
####################################################

# Add the official stable repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update


# Install Helm ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.service.externalTrafficPolicy=Local \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"=$AKS_DNS_LABEL_2 \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
    --wait --timeout 3m0s

echo "apiVersion: apps/v1
kind: Deployment
metadata:
  name: akswordpress-deployment2
spec:
  selector:
    matchLabels:
      app: akswordpress2
  template:
    metadata:
      labels:
        app: akswordpress2
    spec:
      containers:
      - name: akswordpress2
        image: ${ACR_NAME}.azurecr.io/${DOCKER_HUB_IMAGE_NAME}
        env:
        - name: WORDPRESS_DB_HOST
          value: ${MY_MYSQL_SERVER_NAME_2}.${PRIVATE_DNS_ZONE_NAME_2}
        - name: WORDPRESS_DB_NAME
          value: ${MY_MYSQL_DB_NAME_2}
        - name: WORDPRESS_DB_USER
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: username
        - name: WORDPRESS_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "256Mi"
            cpu: "500m"
          limits:
            memory: "512Mi"
            cpu: "1"
" > deployment_2.yaml

echo "apiVersion: v1
kind: Service
metadata:
  name: clustorip-svc-2
  labels: 
    app: akswordpress2  #Has to be same what's labelled in deployment YAML
spec:
  type: ClusterIP 
  selector:
    app: akswordpress2  #Has to be same what's labelled in deployment YAML
  ports: 
    - port: 80        #Service Port
      targetPort: 80     #Container Port defined in Deployment YAML
" > service_2.yaml

echo "apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-svc-2
  annotations:
    kubernetes.io/ingress.class: "nginx"  # Ensures this annotation is correct
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: clustorip-svc-2
                port: 
                  number: 80
" > ingress_2.yaml

# Apply the Deployment, Service, and Ingress in Kubernetes
kubectl apply -f deployment_2.yaml

kubectl apply -f service_2.yaml

kubectl apply -f ingress_2.yaml


#############################################################
############# TRAFFIC MANAGER SECOND ENDPOINT ###############
#############################################################

export second_aks_resource_id=$(az network public-ip list --query "[?dnsSettings.domainNameLabel=='$AKS_DNS_LABEL_2']" | jq -r '.[].id')

# Create a traffic manager endpoint for primary cluster
az network traffic-manager endpoint create \
  --name secondEndpoint \
  --profile-name $TRAFFIC_MANAGER_NAME \
  --resource-group $GLOBAL_RESOURCE_GROUP \
  --type azureEndpoints \
  --priority 2 \
  --endpoint-status Enabled \
  --target-resource-id $second_aks_resource_id
