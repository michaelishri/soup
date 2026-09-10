using MediaBrowser.Model.Plugins;

namespace Jellyfin.Plugin.Soup.Configuration;

/// <summary>
/// Local entitlement row managed by the Jellyfin admin UI.
/// </summary>
public class EntitlementEntry
{
    /// <summary>
    /// Gets or sets a stable local id (GUID string).
    /// </summary>
    public string Id { get; set; } = Guid.NewGuid().ToString("N");

    /// <summary>
    /// Gets or sets the Google account email (join key). Required for Active entitlements.
    /// </summary>
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets a display name sent to Soup as <c>display_name</c>.
    /// </summary>
    public string? DisplayName { get; set; }

    /// <summary>
    /// Gets or sets an optional Jellyfin username hint.
    /// </summary>
    public string? JellyfinUserHint { get; set; }

    /// <summary>
    /// Gets or sets the linked Jellyfin user id once created/linked.
    /// </summary>
    public string? JellyfinUserId { get; set; }

    /// <summary>
    /// Gets or sets entitlement status: <c>Pending</c>, <c>Active</c>, or <c>Revoked</c>.
    /// </summary>
    public string Status { get; set; } = "Pending";

    /// <summary>
    /// Gets or sets whether this row has been upserted to Soup.
    /// </summary>
    public bool SyncedToSoup { get; set; }

    /// <summary>
    /// Gets or sets when the invite was created (UTC ISO-8601).
    /// </summary>
    public string CreatedAtUtc { get; set; } = DateTime.UtcNow.ToString("O");

    /// <summary>
    /// Gets or sets the Tailscale auth-key id from the last mint (for DELETE on revoke).
    /// </summary>
    public string? TailscaleKeyId { get; set; }

    /// <summary>
    /// Gets or sets when a transport grant was last deposited to Soup (UTC ISO-8601).
    /// </summary>
    public string? TransportGrantDepositedAtUtc { get; set; }
}

/// <summary>
/// Plugin configuration persisted by Jellyfin.
/// </summary>
public class PluginConfiguration : BasePluginConfiguration
{
    /// <summary>
    /// Gets or sets the Soup identity base URL (e.g. http://localhost:8787).
    /// </summary>
    public string SoupBaseUrl { get; set; } = "http://localhost:8787";

    /// <summary>
    /// Gets or sets the plugin Basic-auth username (<c>plugin_id</c>).
    /// </summary>
    public string PluginId { get; set; } = "dev-plugin";

    /// <summary>
    /// Gets or sets the plugin Basic-auth password (<c>plugin_secret</c>).
    /// </summary>
    public string PluginSecret { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the Soup server id path segment.
    /// </summary>
    public string ServerId { get; set; } = "home-jf";

    /// <summary>
    /// Gets or sets the human-readable server name registered with Soup.
    /// </summary>
    public string ServerName { get; set; } = "Home";

    /// <summary>
    /// Gets or sets the JWT <c>aud</c> this plugin expects (Soup ServerUpsert.audience).
    /// </summary>
    public string Audience { get; set; } = "jellyfin:home-jf";

    /// <summary>
    /// Gets or sets the expected JWT issuer (Soup <c>ASSERTION_ISSUER</c>).
    /// </summary>
    public string AssertionIssuer { get; set; } = "https://soup.local/identity";

    /// <summary>
    /// Gets or sets optional Jellyfin base URL published to Soup roster.
    /// </summary>
    public string? JellyfinBaseUrl { get; set; }

    /// <summary>
    /// Gets or sets optional MagicDNS / Tailscale hostname published to Soup.
    /// </summary>
    public string? MagicDns { get; set; }

    /// <summary>
    /// Gets or sets a value indicating whether missing Jellyfin users are created on exchange.
    /// </summary>
    public bool CreateMissingUsers { get; set; } = true;

    /// <summary>
    /// Gets or sets the username prefix used when auto-creating users from Google email.
    /// </summary>
    public string UsernamePrefix { get; set; } = "soup-";

    /// <summary>
    /// Gets or sets local entitlement invites (source of truth for admin UI).
    /// </summary>
    public List<EntitlementEntry> Entitlements { get; set; } = [];

    /// <summary>
    /// Gets or sets a value indicating whether invite/sync mints a Tailscale auth key and deposits it to Soup.
    /// Requires OAuth client or API token below.
    /// </summary>
    public bool MintTailscaleAuthKeyOnInvite { get; set; } = true;

    /// <summary>
    /// Gets or sets the Tailscale tailnet slug (use <c>-</c> with OAuth access tokens).
    /// </summary>
    public string TailscaleTailnet { get; set; } = "-";

    /// <summary>
    /// Gets or sets the preferred Tailscale OAuth client id (<c>tskey-client-…</c>).
    /// </summary>
    public string TailscaleOAuthClientId { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the Tailscale OAuth client secret (<c>tskey-client-…</c>).
    /// </summary>
    public string TailscaleOAuthClientSecret { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets an optional long-lived Tailscale user API token (<c>tskey-api-…</c>).
    /// Used only when OAuth client id/secret are empty. Prefer OAuth with <c>auth_keys</c> scope.
    /// </summary>
    public string TailscaleApiToken { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets comma-separated ACL tags applied to minted guest keys (e.g. <c>tag:soup-guest</c>).
    /// Required for OAuth-minted keys.
    /// </summary>
    public string TailscaleGuestTags { get; set; } = "tag:soup-guest";

    /// <summary>
    /// Gets or sets Tailscale auth-key expiry in seconds (recommend 1800).
    /// </summary>
    public int TailscaleAuthKeyExpirySeconds { get; set; } = 1800;
}
