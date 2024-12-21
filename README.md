# ProjectEpsilon
## Project Overview:
A college project worked on as a group of 3 (Daniel Lee, Usman Naveed, and Anthony Li) to create a
highly available, containerized web application using various Azure services.


## Detailed Overview:
Create two seperate AKS cluster that pulls an image from a central ACR that pulls from a Docker
Hub repository. Each cluster runs on seperate regions, accessible through a single Traffic
Manager profile, set with differing priority to follow the Active/Passive strategy (the primary
region will get all the traffic until disaster occurs, then it will failover to the secondary
region). Each cluster will connect to their own Azure DB for MySQL - Flexible Server (for holding
the Wordpress data) and Azure KeyVault (to hold the credentials for Azure DB to allow the AKS cluster
to access it) through individual Private Endpoints. Each cluster and private endpoint will be located
in their own NSG with their own rules to limit inbound traffic.


## To Run:
- If running from cloud shell:
    - Upload project_setup.sh to terminal
    - Run: chmod +x project_setup.sh
    - Run project_setup.sh
- If running from elsewhere:
    - Uncomment line 4: #az login
    - Run project_setup.sh
    - Login to your Azure account when prompted
    - Let the rest of the file run


## Utilized Tools and Azure Services:
- Azure Kubernetes Service
- Azure Container Registry
- Azure Traffic Manager
- Azure MySQL Flexible Server
- Azure Key Vault
- Azure Network Security Groups
- Azure Private Endpoints
- Docker Hub
- Wordpress
