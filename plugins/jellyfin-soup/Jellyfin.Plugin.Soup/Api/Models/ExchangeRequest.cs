namespace Jellyfin.Plugin.Soup.Api.Models;

/// <summary>
/// Body for <c>POST /SoupAuth/Exchange</c>.
/// </summary>
public sealed class ExchangeRequest
{
    /// <summary>
    /// Gets or sets the Soup assertion JWT (compact serialization).
    /// </summary>
    public string Assertion { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the client device id (bound into the Jellyfin session).
    /// </summary>
    public string DeviceId { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the client device name.
    /// </summary>
    public string DeviceName { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the client application name.
    /// </summary>
    public string App { get; set; } = string.Empty;

    /// <summary>
    /// Gets or sets the client application version.
    /// </summary>
    public string AppVersion { get; set; } = string.Empty;
}

/// <summary>
/// Body for inviting an entitlement.
/// </summary>
public sealed class InviteRequest
{
    /// <summary>
    /// Gets or sets the Google OIDC subject. Optional when <see cref="Email"/> is set.
    /// </summary>
    public string? GoogleSub { get; set; }

    /// <summary>
    /// Gets or sets an email invite. Remains Pending until a Google sub is known.
    /// </summary>
    public string? Email { get; set; }

    /// <summary>
    /// Gets or sets a display name.
    /// </summary>
    public string? DisplayName { get; set; }

    /// <summary>
    /// Gets or sets an optional Jellyfin username hint.
    /// </summary>
    public string? JellyfinUserHint { get; set; }
}
