// Based on sample code from https://github.com/microsoft/Agents-for-net

using Microsoft.Agents.CopilotStudio.Client;
using Microsoft.Extensions.Configuration;

namespace CopilotTests
{
    /// <summary>
    /// Connection Settings extension for the test to include authentication details.
    /// </summary>
    internal class TestConnectionSettings : ConnectionSettings
    {
        /// <summary>
        /// Use S2S connection for authentication. If false, uses username/password auth.
        /// </summary>
        public bool UseS2SConnection { get; set; } = false; // Default to username/password for tests

        /// <summary>
        /// Tenant ID for creating the authentication for the connection
        /// </summary>
        public string? TenantId { get; set; }

        /// <summary>
        /// Application ID for creating the authentication for the connection
        /// </summary>
        public string? AppClientId { get; set; }

        /// <summary>
        /// Application secret for creating the authentication for the connection (used for S2S auth)
        /// </summary>
        public string? AppClientSecret { get; set; }

        /// <summary>
        /// Username for user authentication (used for username/password auth)
        /// </summary>
        public string? Username { get; set; }

        /// <summary>
        /// Password for user authentication (used for username/password auth)
        /// </summary>
        public string? Password { get; set; }

        /// <summary>
        /// Create ConnectionSettings with direct properties.
        /// </summary>
        public TestConnectionSettings()
        {
        }

        /// <summary>
        /// Create ConnectionSettings from a configuration section.
        /// </summary>
        /// <param name="config"></param>
        /// <exception cref="System.ArgumentException"></exception>
        public TestConnectionSettings(IConfigurationSection config) : base(config)
        {
            AppClientId = config[nameof(AppClientId)] ?? throw new ArgumentException($"{nameof(AppClientId)} not found in config");
            TenantId = config[nameof(TenantId)] ?? throw new ArgumentException($"{nameof(TenantId)} not found in config");

            UseS2SConnection = config.GetValue<bool>(nameof(UseS2SConnection), false);
            AppClientSecret = config[nameof(AppClientSecret)];
            Username = config[nameof(Username)];
            Password = config[nameof(Password)];
        }
    }
}

