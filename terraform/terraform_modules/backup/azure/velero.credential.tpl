credentials:
    secretContents:
        cloud: |
            AZURE_SUBSCRIPTION_ID=${ARM_SUBSCRIPTION_ID}
            AZURE_TENANT_ID=${ARM_TENANT_ID}
            AZURE_CLIENT_ID=${ARM_CLIENT_ID}
            AZURE_CLIENT_SECRET=${ARM_CLIENT_SECRET}
            AZURE_RESOURCE_GROUP=${AKS_RESOURCE_GROUP}
            AZURE_CLOUD_NAME=AzurePublicCloud