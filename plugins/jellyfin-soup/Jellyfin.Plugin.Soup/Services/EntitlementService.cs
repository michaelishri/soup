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
    /// Invite by Google sub and/or email. Email-only invites stay Pending until a sub is known.
    /// When a Google sub is present, upserts Soup entitlement and optionally mints/deposits a Tailscale grant.
    /// </summary>
    /// <param name="googleSub">Google subject (optional if email provided).</param>
    /// <param name="email">Invite email (optional if googleSub provided).</param>
    /// <param name="displayName">Display name.</param>
    /// <param name="jellyfinUserHint">Optional Jellyfin username hint.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Created or updated entry.</returns>
    public async Task<EntitlementEntry> InviteAsync(
        string? googleSub,
        string? email,
        string? displayName,
        string? jellyfinUserHint,
        CancellationToken cancellationToken = default)
    {
        googleSub = Normalize(googleSub);
        email = Normalize(email);
        if (googleSub is null && email is null)
        {
            throw new ArgumentException("googleSub or email is required");
        }

        var plugin = RequirePlugin();
        EntitlementEntry entry;
        lock (_gate)
        {
            var config = plugin.Configuration;
            entry = config.Entitlements.FirstOrDefault(e =>
                        (googleSub is not null
                         && string.Equals(e.GoogleSub, googleSub, StringComparison.Ordinal))
                        || (email is not null
                            && !string.IsNullOrWhiteSpace(e.Email)
                            && string.Equals(e.Email, email, StringComparison.OrdinalIgnoreCase)))
                    ?? new EntitlementEntry();

            if (!config.Entitlements.Contains(entry))
            {
                config.Entitlements.Add(entry);
            }

            if (googleSub is not null)
            {
                entry.GoogleSub = googleSub;
            }

            if (email is not null)
            {
                entry.Email = email;
            }

            entry.DisplayName = displayName ?? entry.DisplayName;
            entry.JellyfinUserHint = jellyfinUserHint ?? entry.JellyfinUserHint;
            entry.Status = string.IsNullOrWhiteSpace(entry.GoogleSub) ? "Pending" : "Active";
            entry.SyncedToSoup = false;
            plugin.Save();
        }

        if (!string.IsNullOrWhiteSpace(entry.GoogleSub))
        {
            await SyncOneAsync(entry, depositTransport: true, cancellationToken).ConfigureAwait(false);
        }
        else
        {
            _logger.LogInformation(
                "Email invite pending until Google sub is known: {Email}",
                entry.Email);
        }

        return Clone(entry);
    }

    /// <summary>
    /// Revoke a local entitlement: best-effort Tailscale key DELETE, then Soup entitlement DELETE.
    /// </summary>
    /// <param name="idOrGoogleSub">Local id or Google sub.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>True when an entry was found.</returns>
    public async Task<bool> RevokeAsync(string idOrGoogleSub, CancellationToken cancellationToken = default)
    {
        var plugin = RequirePlugin();
        EntitlementEntry? entry;
        string? googleSub;
        string? tailscaleKeyId;
        lock (_gate)
        {
            var config = plugin.Configuration;
            entry = config.Entitlements.FirstOrDefault(e =>
                string.Equals(e.Id, idOrGoogleSub, StringComparison.OrdinalIgnoreCase)
                || string.Equals(e.GoogleSub, idOrGoogleSub, StringComparison.Ordinal));
            if (entry is null)
            {
                return false;
            }

            googleSub = Normalize(entry.GoogleSub);
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

        if (googleSub is not null)
        {
            try
            {
                await _soupApiClient.RevokeEntitlementAsync(googleSub, cancellationToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Soup revoke failed for {GoogleSub}; local revoke kept", googleSub);
            }
        }

        return true;
    }

    /// <summary>
    /// Resolve an entitled local row for a verified assertion subject (activates pending email matches).
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
        var activatedPending = false;
        lock (_gate)
        {
            var config = plugin.Configuration;
            entry = config.Entitlements.FirstOrDefault(e =>
                !string.Equals(e.Status, "Revoked", StringComparison.OrdinalIgnoreCase)
                && string.Equals(e.GoogleSub, claims.GoogleSub, StringComparison.Ordinal));

            if (entry is null && !string.IsNullOrWhiteSpace(claims.Email))
            {
                entry = config.Entitlements.FirstOrDefault(e =>
                    !string.Equals(e.Status, "Revoked", StringComparison.OrdinalIgnoreCase)
                    && string.IsNullOrWhiteSpace(e.GoogleSub)
                    && string.Equals(e.Email, claims.Email, StringComparison.OrdinalIgnoreCase));
                if (entry is not null)
                {
                    entry.GoogleSub = claims.GoogleSub;
                    entry.Status = "Active";
                    entry.SyncedToSoup = false;
                    plugin.Save();
                    activatedPending = true;
                }
            }
        }

        if (entry is null)
        {
            return null;
        }

        if ((!entry.SyncedToSoup || activatedPending) && !string.IsNullOrWhiteSpace(entry.GoogleSub))
        {
            // First activation of a pending email invite should mint+deposit like Invite.
            await SyncOneAsync(entry, depositTransport: activatedPending, cancellationToken)
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
    /// Upsert all Active local entitlements that have a Google sub (does not remint Tailscale keys).
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
                            && !string.IsNullOrWhiteSpace(e.GoogleSub))
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
    /// <param name="idOrGoogleSub">Local id or Google sub.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Updated entry.</returns>
    public async Task<EntitlementEntry> DepositTransportGrantAsync(
        string idOrGoogleSub,
        CancellationToken cancellationToken = default)
    {
        var plugin = RequirePlugin();
        EntitlementEntry entry;
        lock (_gate)
        {
            entry = plugin.Configuration.Entitlements.FirstOrDefault(e =>
                        string.Equals(e.Id, idOrGoogleSub, StringComparison.OrdinalIgnoreCase)
                        || string.Equals(e.GoogleSub, idOrGoogleSub, StringComparison.Ordinal))
                    ?? throw new InvalidOperationException("Entitlement not found");

            if (string.IsNullOrWhiteSpace(entry.GoogleSub)
                || string.Equals(entry.Status, "Revoked", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("Entitlement must be Active with a Google sub to deposit a grant");
            }
        }

        await SyncOneAsync(entry, depositTransport: true, cancellationToken, forceMint: true)
            .ConfigureAwait(false);
        return Clone(RequireLive(entry.Id));
    }

    /// <summary>
    /// Persist a Jellyfin user link onto the entitlement row.
    /// </summary>
    /// <param name="googleSub">Google subject.</param>
    /// <param name="jellyfinUserId">Jellyfin user id.</param>
    public void AttachJellyfinUser(string googleSub, Guid jellyfinUserId)
    {
        var plugin = RequirePlugin();
        lock (_gate)
        {
            var entry = plugin.Configuration.Entitlements.FirstOrDefault(e =>
                string.Equals(e.GoogleSub, googleSub, StringComparison.Ordinal));
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
                entry.GoogleSub,
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
                "Skipping Tailscale mint for {GoogleSub}: credentials not configured",
                entry.GoogleSub);
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
                    "Transport grant already deposited for {GoogleSub} (key {KeyId}); skip remint",
                    live.GoogleSub,
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
            .MintGuestAuthKeyAsync(entry.GoogleSub, cancellationToken)
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
                    entry.GoogleSub,
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
                "Soup transport-grant deposit failed for {GoogleSub}; revoking minted key {KeyId}",
                entry.GoogleSub,
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
            "Deposited Tailscale transport grant for {GoogleSub} (key {KeyId}, ttl {Ttl}s)",
            entry.GoogleSub,
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

    private static EntitlementEntry Clone(EntitlementEntry e) => new()
    {
        Id = e.Id,
        GoogleSub = e.GoogleSub,
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
