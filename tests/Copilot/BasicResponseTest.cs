using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading;
using System.Threading.Tasks;
using Azure.Identity;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using Microsoft.Agents.CopilotStudio.Client;
using Microsoft.Agents.CopilotStudio.Client.Discovery;
using Microsoft.Identity.Client;
using Xunit;

namespace CopilotTests
{
    public class BasicResponseTest
    {
        [Fact]
        public async Task Copilot_Question_Response()
        {
            // This test uses username/password authentication. 
            // Client ID is optional - if not provided, it will use the default Power Platform CLI client ID

            // Retrieve credentials from environment variables
            string? tenantId = Environment.GetEnvironmentVariable("POWER_PLATFORM_TENANT_ID")
                ?? Environment.GetEnvironmentVariable("ARM_TENANT_ID")
                ?? throw new InvalidOperationException("POWER_PLATFORM_TENANT_ID or ARM_TENANT_ID is required");
            string? clientId = Environment.GetEnvironmentVariable("POWER_PLATFORM_CLIENT_ID")
                ?? Environment.GetEnvironmentVariable("ARM_CLIENT_ID"); // Optional for username/password auth
            string? username = Environment.GetEnvironmentVariable("POWER_PLATFORM_USERNAME")
                ?? throw new InvalidOperationException("POWER_PLATFORM_USERNAME is required for user authentication");
            string? password = Environment.GetEnvironmentVariable("POWER_PLATFORM_PASSWORD")
                ?? throw new InvalidOperationException("POWER_PLATFORM_PASSWORD is required for user authentication");
            string endpoint = Environment.GetEnvironmentVariable("COPILOT_STUDIO_ENDPOINT")
                ?? "https://api.copilotstudio.microsoft.com";
            string? environmentId = Environment.GetEnvironmentVariable("POWER_PLATFORM_ENVIRONMENT_ID")
                ?? throw new InvalidOperationException("POWER_PLATFORM_ENVIRONMENT_ID is required");
            string agentId = Environment.GetEnvironmentVariable("COPILOT_STUDIO_AGENT_ID")
                ?? "crf6d_aiSearchConnectionExample"; // fallback

            // Configure connection settings
            TestConnectionSettings settings = new TestConnectionSettings
            {
                EnvironmentId = environmentId,
                SchemaName = agentId,
                TenantId = tenantId,
                AppClientId = clientId,
                Username = username,
                Password = password,
                UseS2SConnection = false, // Use username/password authentication
                Cloud = PowerPlatformCloud.Prod
            };

            // Set up service provider
            ServiceCollection services = new ServiceCollection();

            // Register logging
            services.AddLogging();

            // Create an http client for use by the CopilotClient and add the token handler to the client.
            services.AddHttpClient("mcs").ConfigurePrimaryHttpMessageHandler(() => new AddTokenHandler(settings));

            // Add CopilotClient to services
            services.AddTransient<CopilotClient>((IServiceProvider s) =>
            {
                ILogger<CopilotClient> logger = s.GetRequiredService<ILoggerFactory>().CreateLogger<CopilotClient>();
                return new CopilotClient(settings, s.GetRequiredService<IHttpClientFactory>(), logger, "mcs");
            });

            ServiceProvider serviceProvider = services.BuildServiceProvider();
            CopilotClient client = serviceProvider.GetRequiredService<CopilotClient>();
            ILogger<BasicResponseTest> logger = serviceProvider.GetRequiredService<ILogger<BasicResponseTest>>();

            // Start conversation
            await foreach (var activity in client.StartConversationAsync())
            {
                logger.LogInformation($"Started conversation. Activity type: {activity?.Type}");
                break;
            }

            // Ask specific question and aggregate full response
            string? response = null;
            List<string> responseParts = new List<string>();
            await foreach (var activity in client.AskQuestionAsync("How much is the Adventure Dining Table?"))
            {
                if (!string.IsNullOrEmpty(activity?.Text))
                {
                    responseParts.Add(activity.Text);
                    logger.LogInformation($"Received response part: {activity.Text}");
                }
            }
            response = string.Join(" ", responseParts);

            // Log the complete raw response
            Console.WriteLine($"Complete raw response: {response}");

            // Validate response contains expected value
            Assert.Contains("$90", response);
        }
    }
}