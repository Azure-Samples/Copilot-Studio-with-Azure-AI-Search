// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

using System;
using System.Collections.Generic;
using System.IO;
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
        /// <summary>
        /// Gets configuration value first from environment variables, then from azd .env file
        /// </summary>
        private static string? GetConfigValue(string key, string? defaultValue = null)
        {
            // First try to read from environment variables
            var envVariable = Environment.GetEnvironmentVariable(key);
            if (!string.IsNullOrEmpty(envVariable))
            {
                return envVariable;
            }

            // Fall back to azd .env file
            var envFromFile = ReadFromAzdEnvFile(key);
            if (!string.IsNullOrEmpty(envFromFile))
            {
                return envFromFile;
            }

            return defaultValue;
        }

        /// <summary>
        /// Reads configuration from azd environment .env file
        /// </summary>
        private static string? ReadFromAzdEnvFile(string key)
        {
            try
            {
                // Look for .azure directory in current or parent directories
                var currentDir = Directory.GetCurrentDirectory();
                var azureDir = FindAzureDirectory(currentDir);

                if (azureDir == null)
                {
                    return null;
                }

                // Find the environment directory (should contain .env file)
                var envDirs = Directory.GetDirectories(azureDir);
                foreach (var envDir in envDirs)
                {
                    var envFile = Path.Combine(envDir, ".env");
                    if (File.Exists(envFile))
                    {
                        var value = ReadEnvFileValue(envFile, key);
                        if (!string.IsNullOrEmpty(value))
                        {
                            return value;
                        }
                    }
                }
            }
            catch (Exception)
            {
                // Silently fail and fall back to environment variables
            }

            return null;
        }

        /// <summary>
        /// Finds the .azure directory by walking up the directory tree
        /// </summary>
        private static string? FindAzureDirectory(string startDir)
        {
            var currentDir = startDir;
            while (currentDir != null)
            {
                var azureDir = Path.Combine(currentDir, ".azure");
                if (Directory.Exists(azureDir))
                {
                    return azureDir;
                }

                var parent = Directory.GetParent(currentDir);
                currentDir = parent?.FullName;
            }

            return null;
        }

        /// <summary>
        /// Reads a specific key value from an .env file
        /// </summary>
        private static string? ReadEnvFileValue(string filePath, string key)
        {
            try
            {
                var lines = File.ReadAllLines(filePath);
                foreach (var line in lines)
                {
                    if (string.IsNullOrWhiteSpace(line) || line.StartsWith("#"))
                        continue;

                    var parts = line.Split('=', 2);
                    if (parts.Length == 2 && string.Equals(parts[0].Trim(), key, StringComparison.OrdinalIgnoreCase))
                    {
                        var value = parts[1].Trim();
                        // Remove quotes if present
                        if ((value.StartsWith("\"") && value.EndsWith("\"")) ||
                            (value.StartsWith("'") && value.EndsWith("'")))
                        {
                            value = value.Substring(1, value.Length - 2);
                        }
                        return value;
                    }
                }
            }
            catch (Exception)
            {
                // Silently fail and return null
            }

            return null;
        }

        [Fact]
        public async Task Copilot_Question_Response()
        {
            // This test uses username/password authentication. 
            // Client ID is optional - if not provided, it will use the default Power Platform CLI client ID

            // Retrieve credentials from environment variables or azd .env file
            string? tenantId = GetConfigValue("POWER_PLATFORM_TENANT_ID")
                ?? GetConfigValue("ARM_TENANT_ID")
                ?? GetConfigValue("AZURE_TENANT_ID")
                ?? throw new InvalidOperationException("POWER_PLATFORM_TENANT_ID or ARM_TENANT_ID is required");
            string? nativeClientId = GetConfigValue("TEST_CLIENT_ID");
            string? username = GetConfigValue("POWER_PLATFORM_USERNAME")
                ?? throw new InvalidOperationException("POWER_PLATFORM_USERNAME is required for user authentication");
            string? password = GetConfigValue("POWER_PLATFORM_PASSWORD")
                ?? throw new InvalidOperationException("POWER_PLATFORM_PASSWORD is required for user authentication");
            string endpoint = GetConfigValue("COPILOT_STUDIO_ENDPOINT", "https://api.copilotstudio.microsoft.com")!;
            string? environmentId = GetConfigValue("POWER_PLATFORM_ENVIRONMENT_ID")
                ?? throw new InvalidOperationException("POWER_PLATFORM_ENVIRONMENT_ID is required");
            string agentId = GetConfigValue("COPILOT_STUDIO_AGENT_ID", "crf6d_aiSearchConnectionExample")!; // fallback

            // Configure connection settings
            TestConnectionSettings settings = new TestConnectionSettings
            {
                EnvironmentId = environmentId,
                SchemaName = agentId,
                TenantId = tenantId,
                AppClientId = nativeClientId,
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
