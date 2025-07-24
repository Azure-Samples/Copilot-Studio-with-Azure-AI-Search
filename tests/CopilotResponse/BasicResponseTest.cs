using System;
using System.Threading.Tasks;
using Azure.Core;
using Azure.Identity;
using Microsoft.Agents.CopilotStudio.Client;
using Xunit;

public class BasicResponseTest
{
    [Fact]
    public async Task Copilot_Question_Response()
    {
        // 0. Securely retrieve credentials from environment variables
        var tenantId = Environment.GetEnvironmentVariable("AZURE_TENANT_ID") 
            ?? Environment.GetEnvironmentVariable("ARM_TENANT_ID")
            ?? throw new InvalidOperationException("AZURE_TENANT_ID or ARM_TENANT_ID environment variable is required");
        var clientId = Environment.GetEnvironmentVariable("AZURE_CLIENT_ID") 
            ?? Environment.GetEnvironmentVariable("ARM_CLIENT_ID")
            ?? throw new InvalidOperationException("AZURE_CLIENT_ID or ARM_CLIENT_ID environment variable is required");
        var clientSecret = Environment.GetEnvironmentVariable("AZURE_CLIENT_SECRET") 
            ?? Environment.GetEnvironmentVariable("ARM_CLIENT_SECRET");
        var endpoint = Environment.GetEnvironmentVariable("COPILOT_STUDIO_ENDPOINT") 
            ?? "https://api.copilotstudio.microsoft.com";
        var environmentId = Environment.GetEnvironmentVariable("POWER_PLATFORM_ENVIRONMENT_ID") 
            ?? throw new InvalidOperationException("POWER_PLATFORM_ENVIRONMENT_ID environment variable is required");
        var agentId = Environment.GetEnvironmentVariable("COPILOT_STUDIO_AGENT_ID") 
            ?? "crf6d_aiSearchConnectionExample";  // Default to the solution's bot name
        
        if (string.IsNullOrEmpty(clientSecret))
        {
            throw new InvalidOperationException(
                "AZURE_CLIENT_SECRET or ARM_CLIENT_SECRET environment variable is required. " +
                "This test requires a service principal with client secret for API authentication. " +
                "Federated identity tokens cannot be used directly for Copilot Studio API calls.");
        }
        
        // 1. Acquire token using service principal credentials
        var credential = new ClientSecretCredential(tenantId, clientId, clientSecret);
        var tokenRequestContext = new Azure.Core.TokenRequestContext(
            scopes: new[] { "https://api.copilotstudio.microsoft.com/.default" });

        var tokenResponse = await credential.GetTokenAsync(tokenRequestContext);

        // 2. Set up client with bearer token auth
        var client = new CopilotStudioClient(new Uri(endpoint), new CopilotStudioClientOptions
        {
            Credential = new CopilotStudioTokenCredential(tokenResponse.Token)
        });

        // 3. Start conversation
        var session = await client.Conversations.StartConversationAsync(new ConversationStartRequest
        {
            EnvironmentId = environmentId,
            AgentId = agentId
        });

        // 4. Send a message
        var response = await client.Conversations.SendMessageAsync(session.ConversationId, new MessageRequest
        {
            Text = "How much is the Adventure Dining Table?"
        });

        // 5. Validate response
        Assert.Contains(response.Messages, m => m.Text.Contains("$90"));
    }
}