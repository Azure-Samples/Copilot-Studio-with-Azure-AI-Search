# Alternative Access to Azure AI Search

## Configuring Azure AI Search Access with a Service Principal

By default, an access key is used to establish the connection between Azure AI Search and the Copilot Studio agent. Alternatively, you can configure the connection to use a pre-existing service principal for enhanced security and role-based access control.

When using a service principal, the following roles will be assigned to your service principal:

- **Search Index Data Reader**: Grants read access to the search index.
- **Reader**: Provides read-only access to the Azure resource.

These roles will be utilized in the Power Platform connection to enable secure integration.

> **Note**: In Copilot Studio, the connection status may display an error. This behavior is expected because the service principal authentication is not shared with any end user logged into the web interface.

When choosing this option, the service principal used for module deployment must have the `User Access Administrator` role assigned.

    ```bash
    azd env set AZURE_AI_SEARCH_SERVICE_PRINCIPAL_CLIENT_ID "<Client-ID>"
    azd env set AZURE_AI_SEARCH_ENTERPRISE_APPLICATION_OBJECT_ID "<Object-ID>"
    azd env set AZURE_AI_SEARCH_SERVICE_PRINCIPAL_CLIENT_SECRET "<Client-Secret>"
    ```
