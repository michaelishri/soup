using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Jellyfin.Plugin.Soup.Configuration;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Soup.Services;

/// <summary>
/// Result of minting a Tailscale auth key (key material returned once).
/// </summary>
public sealed class TailscaleAuthKeyMintResult
{
    /// <summary>
    /// Gets the Tailscale key id (e.g. <c>k…CNTRL</c>) for later DELETE.
    /// </summary>
    public required string Id { get; init; }

    /// <summary>
    /// Gets the one-time auth key material (<c>tskey-auth-…</c>).
    /// </summary>
    public required string Key { get; init; }

    /// <summary>
    /// Gets the expiry seconds requested at mint time.
    /// </summary>
    public int ExpirySeconds { get; init; }

    /// <summary>
    /// Gets the tags applied to the key.
    /// </summary>
    public IReadOnlyList<string> Tags { get; init; } = [];
}

/// <summary>
/// Outbound Tailscale control-plane client: OAuth token, auth-key mint, and revoke.
/// </summary>
public sealed class TailscaleApiClient
{
    /// <summary>
    /// Named <see cref="IHttpClientFactory"/> client.
    /// </summary>
    public const string HttpClientName = "TailscaleApi";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private static readonly Regex DescriptionSafe = new("[^a-zA-Z0-9_-]+", RegexOptions.Compiled);

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<TailscaleApiClient> _logger;
    private readonly object _tokenGate = new();
    private string? _cachedAccessToken;
    private DateTimeOffset _cachedAccessTokenExpiresAt = DateTimeOffset.MinValue;

    /// <summary>
    /// Initializes a new instance of the <see cref="TailscaleApiClient"/> class.
    /// </summary>
    /// <param name="httpClientFactory">HTTP client factory.</param>
    /// <param name="logger">Logger.</param>
    public TailscaleApiClient(IHttpClientFactory httpClientFactory, ILogger<TailscaleApiClient> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    /// <summary>
    /// Returns true when the plugin has enough Tailscale credentials to mint keys.
    /// </summary>
    /// <param name="config">Plugin configuration.</param>
    /// <returns>Whether minting is possible.</returns>
    public static bool IsConfigured(PluginConfiguration config)
    {
        if (!string.IsNullOrWhiteSpace(config.TailscaleOAuthClientId)
            && !string.IsNullOrWhiteSpace(config.TailscaleOAuthClientSecret))
        {
            return true;
        }

        return !string.IsNullOrWhiteSpace(config.TailscaleApiToken);
    }

    /// <summary>
    /// Mint a single-use, ephemeral, preauthorized, tagged auth key.
    /// </summary>
    /// <param name="email">Google email used for description / audit.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Mint result including one-time key material.</returns>
    public async Task<TailscaleAuthKeyMintResult> MintGuestAuthKeyAsync(
        string email,
        CancellationToken cancellationToken = default)
    {
        var config = RequireConfig();
        if (!IsConfigured(config))
        {
            throw new InvalidOperationException(
                "Tailscale credentials are not configured (OAuth client or API token)");
        }

        var tags = ParseTags(config.TailscaleGuestTags);
        if (tags.Count == 0)
        {
            throw new InvalidOperationException("TailscaleGuestTags must include at least one tag (e.g. tag:soup-guest)");
        }

        var expirySeconds = config.TailscaleAuthKeyExpirySeconds;
        if (expirySeconds < 60)
        {
            expirySeconds = 60;
        }

        var accessToken = await ResolveAccessTokenAsync(config, cancellationToken).ConfigureAwait(false);
        var tailnet = string.IsNullOrWhiteSpace(config.TailscaleTailnet) ? "-" : config.TailscaleTailnet.Trim();
        var description = BuildDescription(email);

        var body = new Dictionary<string, object?>
        {
            ["capabilities"] = new Dictionary<string, object?>
            {
                ["devices"] = new Dictionary<string, object?>
                {
                    ["create"] = new Dictionary<string, object?>
                    {
                        ["reusable"] = false,
                        ["ephemeral"] = true,
                        ["preauthorized"] = true,
                        ["tags"] = tags
                    }
                }
            },
            ["expirySeconds"] = expirySeconds,
            ["description"] = description
        };

        var client = _httpClientFactory.CreateClient(HttpClientName);
        using var request = new HttpRequestMessage(
            HttpMethod.Post,
            $"https://api.tailscale.com/api/v2/tailnet/{Uri.EscapeDataString(tailnet)}/keys");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        request.Content = JsonContent.Create(body, options: JsonOptions);

        using var response = await client.SendAsync(request, cancellationToken).ConfigureAwait(false);
        var text = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError(
                "Tailscale mint failed: {Status} {Body}",
                (int)response.StatusCode,
                SecretRedactor.Redact(text));
            throw new InvalidOperationException(
                $"Tailscale mint failed with {(int)response.StatusCode}");
        }

        using var doc = JsonDocument.Parse(text);
        var root = doc.RootElement;
        var id = root.GetProperty("id").GetString()
            ?? throw new InvalidOperationException("Tailscale mint response missing id");
        // Material is returned to the caller once; never log the key field.
        var key = root.GetProperty("key").GetString()
            ?? throw new InvalidOperationException("Tailscale mint response missing key");

        _logger.LogInformation(
            "Minted Tailscale auth key {KeyId} for Google email {Email} (expiry {Expiry}s)",
            id,
            email,
            expirySeconds);

        return new TailscaleAuthKeyMintResult
        {
            Id = id,
            Key = key,
            ExpirySeconds = expirySeconds,
            Tags = tags
        };
    }

    /// <summary>
    /// DELETE an unused Tailscale auth key by id (best-effort revoke/cleanup).
    /// </summary>
    /// <param name="keyId">Tailscale key id.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A task representing the asynchronous operation.</returns>
    public async Task RevokeAuthKeyAsync(string keyId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(keyId))
        {
            return;
        }

        var config = RequireConfig();
        if (!IsConfigured(config))
        {
            _logger.LogWarning("Cannot revoke Tailscale key {KeyId}: credentials not configured", keyId);
            return;
        }

        var accessToken = await ResolveAccessTokenAsync(config, cancellationToken).ConfigureAwait(false);
        var tailnet = string.IsNullOrWhiteSpace(config.TailscaleTailnet) ? "-" : config.TailscaleTailnet.Trim();

        var client = _httpClientFactory.CreateClient(HttpClientName);
        using var request = new HttpRequestMessage(
            HttpMethod.Delete,
            $"https://api.tailscale.com/api/v2/tailnet/{Uri.EscapeDataString(tailnet)}/keys/{Uri.EscapeDataString(keyId)}");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        using var response = await client.SendAsync(request, cancellationToken).ConfigureAwait(false);
        if (response.IsSuccessStatusCode || response.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            _logger.LogInformation("Revoked Tailscale auth key {KeyId} (status {Status})", keyId, (int)response.StatusCode);
            return;
        }

        var text = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
        _logger.LogWarning(
            "Tailscale key revoke failed for {KeyId}: {Status} {Body}",
            keyId,
            (int)response.StatusCode,
            SecretRedactor.Redact(text));
        throw new InvalidOperationException(
            $"Tailscale revoke failed with {(int)response.StatusCode}");
    }

    private async Task<string> ResolveAccessTokenAsync(
        PluginConfiguration config,
        CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(config.TailscaleOAuthClientId)
            && !string.IsNullOrWhiteSpace(config.TailscaleOAuthClientSecret))
        {
            lock (_tokenGate)
            {
                if (!string.IsNullOrEmpty(_cachedAccessToken)
                    && _cachedAccessTokenExpiresAt > DateTimeOffset.UtcNow.AddMinutes(2))
                {
                    return _cachedAccessToken;
                }
            }

            var client = _httpClientFactory.CreateClient(HttpClientName);
            using var content = new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["client_id"] = config.TailscaleOAuthClientId.Trim(),
                ["client_secret"] = config.TailscaleOAuthClientSecret.Trim()
            });
            using var response = await client
                .PostAsync("https://api.tailscale.com/api/v2/oauth/token", content, cancellationToken)
                .ConfigureAwait(false);
            var text = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError(
                    "Tailscale OAuth token failed: {Status} {Body}",
                    (int)response.StatusCode,
                    SecretRedactor.Redact(text));
                throw new InvalidOperationException(
                    $"Tailscale OAuth token failed with {(int)response.StatusCode}");
            }

            using var doc = JsonDocument.Parse(text);
            var accessToken = doc.RootElement.GetProperty("access_token").GetString()
                ?? throw new InvalidOperationException("Tailscale OAuth response missing access_token");
            var expiresIn = 3600;
            if (doc.RootElement.TryGetProperty("expires_in", out var expiresEl)
                && expiresEl.TryGetInt32(out var parsed))
            {
                expiresIn = parsed;
            }

            lock (_tokenGate)
            {
                _cachedAccessToken = accessToken;
                _cachedAccessTokenExpiresAt = DateTimeOffset.UtcNow.AddSeconds(expiresIn);
            }

            return accessToken;
        }

        return config.TailscaleApiToken.Trim();
    }

    private static PluginConfiguration RequireConfig()
        => Plugin.Instance?.Configuration
           ?? throw new InvalidOperationException("Soup plugin is not loaded");

    private static List<string> ParseTags(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            return [];
        }

        return raw.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(t => t.StartsWith("tag:", StringComparison.Ordinal))
            .Distinct(StringComparer.Ordinal)
            .ToList();
    }

    private static string BuildDescription(string email)
    {
        var shortSub = DescriptionSafe.Replace(email, string.Empty);
        if (shortSub.Length > 24)
        {
            shortSub = shortSub[..24];
        }

        if (string.IsNullOrWhiteSpace(shortSub))
        {
            shortSub = "guest";
        }

        var description = "soup-" + shortSub;
        return description.Length <= 50 ? description : description[..50];
    }
}
