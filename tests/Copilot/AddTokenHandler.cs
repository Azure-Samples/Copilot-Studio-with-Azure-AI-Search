// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

// Based on sample code from https://github.com/microsoft/Agents-for-net

using Microsoft.Agents.CopilotStudio.Client;
using System.Net.Http.Headers;
using Microsoft.Identity.Client;

namespace CopilotTests
{
    /// <summary>
    /// This test uses an HttpClientHandler to add an authentication token to the request.
    /// Supports both client secret (S2S) and username/password authentication.
    /// </summary>
    /// <param name="settings">Direct To engine connection settings.</param>
    internal class AddTokenHandler(TestConnectionSettings settings) : DelegatingHandler(new HttpClientHandler())
    {
        private IConfidentialClientApplication? _confidentialClientApplication;
        private IPublicClientApplication? _publicClientApplication;
        private string[]? _scopes;

        private async Task<AuthenticationResult> AuthenticateAsync(CancellationToken ct = default!)
        {
            ArgumentNullException.ThrowIfNull(settings);
            _scopes = [CopilotClient.ScopeFromSettings(settings)];

            AuthenticationResult authResponse;

            try
            {
                if (settings.UseS2SConnection)
                {
                    // Service Principal (Client Credentials) authentication
                    if (_confidentialClientApplication == null)
                    {
                        _confidentialClientApplication = ConfidentialClientApplicationBuilder.Create(settings.AppClientId)
                            .WithAuthority(AzureCloudInstance.AzurePublic, settings.TenantId)
                            .WithClientSecret(settings.AppClientSecret)
                            .Build();
                    }
                    authResponse = await _confidentialClientApplication.AcquireTokenForClient(_scopes).ExecuteAsync(ct);
                }
                else
                {
                    // Username/Password authentication                  
                    _publicClientApplication ??= PublicClientApplicationBuilder.Create(settings.AppClientId)
                        .WithAuthority(AzureCloudInstance.AzurePublic, settings.TenantId)
                        .Build();

                    authResponse = await _publicClientApplication
                        .AcquireTokenByUsernamePassword(_scopes, settings.Username, settings.Password)
                        .ExecuteAsync(ct);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Authentication failed: {ex.GetType().Name}");
                throw;
            }

            return authResponse;
        }

        /// <summary>
        /// Handles sending the request and adding the token to the request.
        /// </summary>
        /// <param name="request">Request to be sent</param>
        /// <param name="cancellationToken">Cancellation token</param>
        /// <returns></returns>
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var authResponse = await AuthenticateAsync(cancellationToken);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", authResponse.AccessToken);

            return await base.SendAsync(request, cancellationToken);
        }
    }
}

