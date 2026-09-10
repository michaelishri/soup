using Jellyfin.Plugin.Soup.Configuration;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Soup.Services;

/// <summary>
/// Local invite/revoke store plus outbound Soup upsert/delete and Tailscale mint/deposit.
/// </summary>
public sealed class EntitlementService
{
    private readonly SoupApiClient _soupApiClient;
    private readonly TailscaleApiClient _tailscaleApiClient;
    private readonly ILogger<EntitlementService> _logger;
    private readonly object _gate = new();

    /// <summary>
    /// Initializes a new instance of the <see cref="EntitlementService"/> class.
    /// </summary>
    /// <param name="soupApiClient">Soup API client.</param>
    /// <param name="tailscaleApiClient">Tailscale API client.</param>
    /// <param name="logger">Logger.</param>
    public EntitlementService(
        SoupApiClient soupApiClient,
        TailscaleApiClient tailscaleApiClient,
        ILogger<EntitlementService> logger)
    {
        _soupApiClient = soupApiClient;
        _tailscaleApiClient = tailscaleApiClient;
        _logger = logger;
    }

    /// <summary>
    /// List non-revoked entitlements.
    /// </summary>
    /// <returns>Entitlement entries.</returns>
    public IReadOnlyList<EntitlementEntry> List()
    {
        var config = RequirePlugin().Configuration;
        lock (_gate)
        {
            return config.Entitlements
                .Where(e => !string.Equals(e.Status, "Revoked", StringComparison.OrdinalIgnoreCase))
                .Select(Clone)
                .ToList();
        }
    }

    /// <summary>
    /// Invite by Google email. Upserts Soup entitlement and optionally mints/deposits a Tailscale grant.
    /// </summary>
    /// <param name="email">Google account email.</param>
    /// <param name="displayName">Display name.</param>
    /// <param name="jellyfinUserHint">Optional Jellyfin username hint.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Created or updated entry.</returns>
    public async Task<EntitlementEntry> InviteAsync(
        string? email,
        string? displayName,
        string? jellyfinUserHint,
        CancellationToken cancellationToken = default)
    {
        email = NormalizeEmail(email);
        if (email is null)
        {
            throw new ArgumentException("email is required");
        }

        var plugin = RequirePlugin();
        EntitlementEntry entry;
        lock (_gate)
        {
            var config = plugin.Configuration;
            entry = config.Entitlements.FirstOrDefault(e =>
                        !string.IsNullOrWhiteSpace(e.Email)
                        && string.Equals(e.Email, email, StringComparison.OrdinalIgnoreCase))
                    ?? new EntitlementEntry();

            if (!config.Entitlements.Contains(entry))
            {
                config.Entitlements.Add(entry);
            }

            entry.Email = email;
            entry.DisplayName = displayName ?? entry.DisplayName;
            entry.JellyfinUserHint = jellyfinUserHint ?? entry.JellyfinUserHint;
            entry.Status = "Active";
            entry.SyncedToSoup = false;
            plugin.Save();
        }

        await SyncOneAsync(entry, depositTransport: true, cancellationToken).ConfigureAwait(false);
        return Clone(entry);
    }

    /// <summary>
    /// Revoke a local entitlement: best-effort Tailscale key DELETE, then Soup entitlement DELETE.
    /// </summary>
    /// <param name="idOrEmail">Local id or Google email.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>True when an entry was found.</returns>
    public async Task<bool> RevokeAsync(string idOrEmail, CancellationToken cancellationToken = default)
    {
        var plugin = RequirePlugin();
        EntitlementEntry? entry;
        string? email;
        string? tailscaleKeyId;
        lock (_gate)
        {
            var config = plugin.Configuration;
            entry = config.Entitlements.FirstOrDefault(e =>
                string.Equals(e.Id, idOrEmail, StringComparison.OrdinalIgnoreCase)
                || string.Equals(e.Email, idOrEmail, StringComparison.OrdinalIgnoreCase));
            if (entry is null)
            {
                return false;
            }

            email = NormalizeEmail(entry.Email);
            tailscaleKeyId = Normalize(entry.TailscaleKeyId);
            entry.Status = "Revoked";
            entry.SyncedToSoup = false;
            entry.TailscaleKeyId = null;
            entry.TransportGrantDepositedAtUtc = null;
            plugin.Save();
        }

        if (tailscaleKeyId is not null)
        {
            try
            {
                await _tailscaleApiClient.RevokeAuthKeyAsync(tailscaleKeyId, cancellationToken)
                    .ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(
                    ex,
                    "Tailscale key revoke failed for {KeyId}; continuing with Soup revoke",
                    tailscaleKeyId);
            }
        }

        if (email is not null)
        {
            try
            {
                await _soupApiClient.RevokeEntitlementAsync(email, cancellationToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Soup revoke failed for {Email}; local revoke kept", email);
            }
        }

        return true;
    }

    /// <summary>
    /// Resolve a local entitlement for a verified Soup assertion (match by email).
    /// </summary>
    /// <param name="claims">Verified assertion claims.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Matching entitlement or null.</returns>
    public async Task<EntitlementEntry?> ResolveForAssertionAsync(
        AssertionClaims claims,
        CancellationToken cancellationToken = default)
    {
        var plugin = RequirePlugin();
        EntitlementEntry? entry;
        lock (_gate)
        {
            var config = plugin.Configuration;
            entry = config.Entitlements.FirstOrDefault(e =>
                !string.Equals(e.Status, "Revoked", StringComparison.OrdinalIgnoreCase)
                && string.Equals(e.Email, claims.Email, StringComparison.OrdinalIgnoreCase));
        }

        if (entry is null)
        {
            return null;
        }

        if (!entry.SyncedToSoup)
        {
            await SyncOneAsync(entry, depositTransport: true, cancellationToken)
                .ConfigureAwait(false);
        }

        return Clone(entry);
    }

    /// <summary>
    /// Register this server with Soup using current config.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A task representing the asynchronous operation.</returns>
    public Task RegisterServerAsync(CancellationToken cancellationToken = default)
        => _soupApiClient.RegisterServerAsync(cancellationToken);

    /// <summary>
    /// Upsert all Active local entitlements that have an email (does not remint Tailscale keys).
    /// </summary>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Number of synced rows.</returns>
    public async Task<int> SyncAllAsync(CancellationToken cancellationToken = default)
    {
        await RegisterServerAsync(cancellationToken).ConfigureAwait(false);
        List<EntitlementEntry> snapshot;
        lock (_gate)
        {
            snapshot = RequirePlugin().Configuration.Entitlements
                .Where(e => string.Equals(e.Status, "Active", StringComparison.OrdinalIgnoreCase)
                            && !string.IsNullOrWhiteSpace(e.Email))
                .ToList();
        }

        var count = 0;
        foreach (var entry in snapshot)
        {
            await SyncOneAsync(entry, depositTransport: false, cancellationToken).ConfigureAwait(false);
            count++;
        }

        return count;
    }

    /// <summary>
    /// Mint a fresh Tailscale auth key and deposit it as a Soup transport grant for an existing entitlement.
    /// </summary>
    /// <param name="idOrEmail">Local id or Google email.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Updated entry.</returns>
    public async Task<EntitlementEntry> DepositTransportGrantAsync(
        string idOrEmail,
        CancellationToken cancellationToken = default)
    {
        var plugin = RequirePlugin();
        EntitlementEntry entry;
        lock (_gate)
        {
            entry = plugin.Configuration.Entitlements.FirstOrDefault(e =>
                        string.Equals(e.Id, idOrEmail, StringComparison.OrdinalIgnoreCase)
                        || string.Equals(e.Email, idOrEmail, StringComparison.Ordinal))
                    ?? throw new InvalidOperationException("Entitlement not found");

            if (string.IsNullOrWhiteSpace(entry.Email)
                || string.Equals(entry.Status, "Revoked", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("Entitlement must be Active with a Google email to deposit a grant");
            }
        }

        await SyncOneAsync(entry, depositTransport: true, cancellationToken, forceMint: true)
            .ConfigureAwait(false);
        return Clone(RequireLive(entry.Id));
    }

    /// <summary>
    /// Persist a Jellyfin user link onto the entitlement row.
    /// </summary>
    /// <param name="email">Google email.</param>
    /// <param name="jellyfinUserId">Jellyfin user id.</param>
    public void AttachJellyfinUser(string email, Guid jellyfinUserId)
    {
        var plugin = RequirePlugin();
        lock (_gate)
        {
            var entry = plugin.Configuration.Entitlements.FirstOrDefault(e =>
                string.Equals(e.Email, email, StringComparison.Ordinal));
            if (entry is null)
            {
                return;
            }

            entry.JellyfinUserId = jellyfinUserId.ToString("N");
            plugin.Save();
        }
    }

    private async Task SyncOneAsync(
        EntitlementEntry entry,
        bool depositTransport,
        CancellationToken cancellationToken,
        bool forceMint = false)
    {
        await _soupApiClient.UpsertEntitlementAsync(
                entry.Email,
                entry.DisplayName,
                entry.JellyfinUserHint,
                cancellationToken)
            .ConfigureAwait(false);

        var plugin = RequirePlugin();
        var config = plugin.Configuration;

        if (depositTransport
            && config.MintTailscaleAuthKeyOnInvite
            && TailscaleApiClient.IsConfigured(config))
        {
            await MintAndDepositAsync(entry, forceMint, cancellationToken).ConfigureAwait(false);
        }
        else if (depositTransport
                 && config.MintTailscaleAuthKeyOnInvite
                 && !TailscaleApiClient.IsConfigured(config))
        {
            _logger.LogInformation(
                "Skipping Tailscale mint for {Email}: credentials not configured",
                entry.Email);
        }

        lock (_gate)
        {
            var live = plugin.Configuration.Entitlements.FirstOrDefault(e => e.Id == entry.Id);
            if (live is not null)
            {
                live.SyncedToSoup = true;
                live.Status = "Active";
                plugin.Save();
            }
        }
    }

    private async Task MintAndDepositAsync(
        EntitlementEntry entry,
        bool forceMint,
        CancellationToken cancellationToken)
    {
        var plugin = RequirePlugin();
        string? previousKeyId;
        lock (_gate)
        {
            var live = plugin.Configuration.Entitlements.FirstOrDefault(e => e.Id == entry.Id)
                       ?? throw new InvalidOperationException("Entitlement disappeared during mint");
            previousKeyId = Normalize(live.TailscaleKeyId);

            // Avoid reminting on every invite upsert unless forced (explicit remint API).
            if (!forceMint
                && !string.IsNullOrWhiteSpace(live.TailscaleKeyId)
                && !string.IsNullOrWhiteSpace(live.TransportGrantDepositedAtUtc))
            {
                _logger.LogInformation(
                    "Transport grant already deposited for {Email} (key {KeyId}); skip remint",
                    live.Email,
                    live.TailscaleKeyId);
                return;
            }
        }

        if (previousKeyId is not null)
        {
            try
            {
                await _tailscaleApiClient.RevokeAuthKeyAsync(previousKeyId, cancellationToken)
                    .ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to revoke previous Tailscale key {KeyId} before remint", previousKeyId);
            }
        }

        var mint = await _tailscaleApiClient
            .MintGuestAuthKeyAsync(entry.Email, cancellationToken)
            .ConfigureAwait(false);

        // Soup TTL expires slightly before the Tailscale key so the mailbox closes first.
        var ttlSeconds = Math.Max(60, Math.Min(1800, mint.ExpirySeconds - 60));
        if (mint.ExpirySeconds <= 60)
        {
            ttlSeconds = mint.ExpirySeconds;
        }

        var capabilities = new Dictionary<string, object?>
        {
            ["reusable"] = false,
            ["ephemeral"] = true,
            ["preauthorized"] = true,
            ["tags"] = mint.Tags
        };

        try
        {
            await _soupApiClient.DepositTransportGrantAsync(
                    entry.Email,
                    "tailscale_auth_key",
                    mint.Key,
                    ttlSeconds,
                    mint.Id,
                    capabilities,
                    cancellationToken)
                .ConfigureAwait(false);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Soup transport-grant deposit failed for {Email}; revoking minted key {KeyId}",
                entry.Email,
                mint.Id);
            try
            {
                await _tailscaleApiClient.RevokeAuthKeyAsync(mint.Id, cancellationToken).ConfigureAwait(false);
            }
            catch (Exception revokeEx)
            {
                _logger.LogWarning(revokeEx, "Cleanup revoke of {KeyId} also failed", mint.Id);
            }

            throw;
        }

        lock (_gate)
        {
            var live = plugin.Configuration.Entitlements.FirstOrDefault(e => e.Id == entry.Id);
            if (live is not null)
            {
                live.TailscaleKeyId = mint.Id;
                live.TransportGrantDepositedAtUtc = DateTime.UtcNow.ToString("O");
                plugin.Save();
            }
        }

        _logger.LogInformation(
            "Deposited Tailscale transport grant for {Email} (key {KeyId}, ttl {Ttl}s)",
            entry.Email,
            mint.Id,
            ttlSeconds);
    }

    private EntitlementEntry RequireLive(string id)
    {
        lock (_gate)
        {
            return RequirePlugin().Configuration.Entitlements.FirstOrDefault(e => e.Id == id)
                   ?? throw new InvalidOperationException("Entitlement not found");
        }
    }

    private static Plugin RequirePlugin()
        => Plugin.Instance ?? throw new InvalidOperationException("Soup plugin is not loaded");

    private static string? Normalize(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static string? NormalizeEmail(string? value)
    {
        var trimmed = Normalize(value);
        return trimmed?.ToLowerInvariant();
    }

    private static EntitlementEntry Clone(EntitlementEntry e) => new()
    {
        Id = e.Id,
        Email = e.Email,
        DisplayName = e.DisplayName,
        JellyfinUserHint = e.JellyfinUserHint,
        JellyfinUserId = e.JellyfinUserId,
        Status = e.Status,
        SyncedToSoup = e.SyncedToSoup,
        CreatedAtUtc = e.CreatedAtUtc,
        TailscaleKeyId = e.TailscaleKeyId,
        TransportGrantDepositedAtUtc = e.TransportGrantDepositedAtUtc
    };
}
