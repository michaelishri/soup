using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Jellyfin.Plugin.Soup.Configuration;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Soup.Services;

/// <summary>
/// Outbound HTTP client for Soup Identity plugin APIs (OpenAPI plugin tag).
/// </summary>
public sealed class SoupApiClient
{
    /// <summary>
    /// Named <see cref="IHttpClientFactory"/> client.
    /// </summary>
    public const string HttpClientName = "SoupIdentity";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<SoupApiClient> _logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="SoupApiClient"/> class.
    /// </summary>
    /// <param name="httpClientFactory">HTTP client factory.</param>
    /// <param name="logger">Logger.</param>
    public SoupApiClient(IHttpClientFactory httpClientFactory, ILogger<SoupApiClient> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    /// <summary>
    /// PUT /v1/servers/{serverId} — register or update this Jellyfin server.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Soup server record JSON.</returns>
    public async Task<JsonElement> RegisterServerAsync(CancellationToken cancellationToken = default)
    {
        var config = RequireConfig();
        var body = new Dictionary<string, object?>
        {
            ["name"] = config.ServerName,
            ["audience"] = config.Audience,
            ["base_url"] = string.IsNullOrWhiteSpace(config.JellyfinBaseUrl) ? null : config.JellyfinBaseUrl,
            ["magic_dns"] = string.IsNullOrWhiteSpace(config.MagicDns) ? null : config.MagicDns
        };

        return await SendAsync(
                HttpMethod.Put,
                $"/v1/servers/{Uri.EscapeDataString(config.ServerId)}",
                body,
                cancellationToken)
            .ConfigureAwait(false);
    }

    /// <summary>
    /// PUT /v1/servers/{serverId}/entitlements/{googleSub}.
    /// </summary>
    /// <param name="googleSub">Google subject.</param>
    /// <param name="displayName">Optional display name.</param>
    /// <param name="jellyfinUserHint">Optional Jellyfin username hint.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Entitlement record JSON.</returns>
    public async Task<JsonElement> UpsertEntitlementAsync(
        string googleSub,
        string? displayName,
        string? jellyfinUserHint,
        CancellationToken cancellationToken = default)
    {
        var config = RequireConfig();
        var body = new Dictionary<string, object?>
        {
            ["display_name"] = displayName,
            ["jellyfin_user_hint"] = jellyfinUserHint
        };

        return await SendAsync(
                HttpMethod.Put,
                $"/v1/servers/{Uri.EscapeDataString(config.ServerId)}/entitlements/{Uri.EscapeDataString(googleSub)}",
                body,
                cancellationToken)
            .ConfigureAwait(false);
    }

    /// <summary>
    /// DELETE /v1/servers/{serverId}/entitlements/{googleSub}.
    /// </summary>
    /// <param name="googleSub">Google subject.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A task representing the asynchronous operation.</returns>
    public async Task RevokeEntitlementAsync(string googleSub, CancellationToken cancellationToken = default)
    {
        var config = RequireConfig();
        await SendAsync(
                HttpMethod.Delete,
                $"/v1/servers/{Uri.EscapeDataString(config.ServerId)}/entitlements/{Uri.EscapeDataString(googleSub)}",
                body: null,
                cancellationToken,
                allowNoContent: true)
            .ConfigureAwait(false);
    }

    /// <summary>
    /// POST /v1/servers/{serverId}/entitlements/{googleSub}/transport-grants
    /// </summary>
    /// <param name="googleSub">Google subject.</param>
    /// <param name="grantType">Grant type (e.g. <c>tailscale_auth_key</c>).</param>
    /// <param name="material">One-time grant material (auth key).</param>
    /// <param name="ttlSeconds">Soup grant TTL (should be ≤ Tailscale key expiry).</param>
    /// <param name="tailscaleKeyId">Optional Tailscale key id for audit / later revoke.</param>
    /// <param name="capabilities">Optional mint capability echo for audit.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Transport grant record JSON (material omitted on subsequent list).</returns>
    public async Task<JsonElement> DepositTransportGrantAsync(
        string googleSub,
        string grantType,
        string material,
        int ttlSeconds,
        string? tailscaleKeyId = null,
        object? capabilities = null,
        CancellationToken cancellationToken = default)
    {
        var config = RequireConfig();
        var body = new Dictionary<string, object?>
        {
            ["grant_type"] = grantType,
            ["material"] = material,
            ["ttl_seconds"] = ttlSeconds,
            ["tailscale_key_id"] = string.IsNullOrWhiteSpace(tailscaleKeyId) ? null : tailscaleKeyId,
            ["capabilities"] = capabilities,
            ["single_claim"] = true
        };

        return await SendAsync(
                HttpMethod.Post,
                $"/v1/servers/{Uri.EscapeDataString(config.ServerId)}/entitlements/{Uri.EscapeDataString(googleSub)}/transport-grants",
                body,
                cancellationToken)
            .ConfigureAwait(false);
    }

    /// <summary>
    /// GET /.well-known/jwks.json
    /// </summary>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Raw JWKS JSON.</returns>
    public async Task<string> FetchJwksAsync(CancellationToken cancellationToken = default)
    {
        var config = RequireConfig();
        var client = CreateClient(config);
        using var response = await client.GetAsync("/.well-known/jwks.json", cancellationToken).ConfigureAwait(false);
        var text = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError("JWKS fetch failed: {Status} {Body}", (int)response.StatusCode, SecretRedactor.Redact(text));
            throw new InvalidOperationException($"Soup JWKS fetch failed with {(int)response.StatusCode}");
        }

        return text;
    }

    private async Task<JsonElement> SendAsync(
        HttpMethod method,
        string path,
        object? body,
        CancellationToken cancellationToken,
        bool allowNoContent = false)
    {
        var config = RequireConfig();
        var client = CreateClient(config);
        using var request = new HttpRequestMessage(method, path);
        request.Headers.Authorization = BuildBasicAuth(config);
        if (body is not null)
        {
            request.Content = JsonContent.Create(body, options: JsonOptions);
        }

        using var response = await client.SendAsync(request, cancellationToken).ConfigureAwait(false);
        var text = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

        if (allowNoContent && response.StatusCode == System.Net.HttpStatusCode.NoContent)
        {
            return default;
        }

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError(
                "Soup API {Method} {Path} failed: {Status} {Body}",
                method,
                path,
                (int)response.StatusCode,
                SecretRedactor.Redact(text));
            throw new InvalidOperationException($"Soup API {(int)response.StatusCode}");
        }

        if (string.IsNullOrWhiteSpace(text))
        {
            return default;
        }

        using var doc = JsonDocument.Parse(text);
        return doc.RootElement.Clone();
    }

    private HttpClient CreateClient(PluginConfiguration config)
    {
        var client = _httpClientFactory.CreateClient(HttpClientName);
        client.BaseAddress = new Uri(TrimSlash(config.SoupBaseUrl) + "/");
        return client;
    }

    private static AuthenticationHeaderValue BuildBasicAuth(PluginConfiguration config)
    {
        var raw = $"{config.PluginId}:{config.PluginSecret}";
        var token = Convert.ToBase64String(Encoding.UTF8.GetBytes(raw));
        return new AuthenticationHeaderValue("Basic", token);
    }

    private static PluginConfiguration RequireConfig()
    {
        var config = Plugin.Instance?.Configuration
            ?? throw new InvalidOperationException("Soup plugin is not loaded");
        if (string.IsNullOrWhiteSpace(config.SoupBaseUrl))
        {
            throw new InvalidOperationException("SoupBaseUrl is not configured");
        }

        if (string.IsNullOrWhiteSpace(config.PluginId) || string.IsNullOrWhiteSpace(config.PluginSecret))
        {
            throw new InvalidOperationException("PluginId/PluginSecret are not configured");
        }

        if (string.IsNullOrWhiteSpace(config.ServerId) || string.IsNullOrWhiteSpace(config.Audience))
        {
            throw new InvalidOperationException("ServerId/Audience are not configured");
        }

        return config;
    }

    private static string TrimSlash(string url) => url.TrimEnd('/');
}
