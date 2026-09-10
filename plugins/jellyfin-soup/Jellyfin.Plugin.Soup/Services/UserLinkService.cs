using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using Jellyfin.Database.Implementations.Entities;
using Jellyfin.Plugin.Soup.Configuration;
using MediaBrowser.Controller.Library;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Soup.Services;

/// <summary>
/// Maps Google subjects to Jellyfin users (create or link).
/// </summary>
public sealed class UserLinkService
{
    private static readonly Regex SafeName = new("[^a-zA-Z0-9._-]+", RegexOptions.Compiled);

    private readonly IUserManager _userManager;
    private readonly ILogger<UserLinkService> _logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="UserLinkService"/> class.
    /// </summary>
    /// <param name="userManager">Jellyfin user manager.</param>
    /// <param name="logger">Logger.</param>
    public UserLinkService(IUserManager userManager, ILogger<UserLinkService> logger)
    {
        _userManager = userManager;
        _logger = logger;
    }

    /// <summary>
    /// Resolve or create a Jellyfin user for an entitled Google subject.
    /// </summary>
    /// <param name="entry">Local entitlement.</param>
    /// <param name="claims">Verified assertion claims.</param>
    /// <returns>Jellyfin user.</returns>
    public async Task<User> ResolveOrCreateAsync(EntitlementEntry entry, AssertionClaims claims)
    {
        var config = Plugin.Instance?.Configuration
            ?? throw new InvalidOperationException("Soup plugin is not loaded");

        if (!string.IsNullOrWhiteSpace(entry.JellyfinUserId)
            && Guid.TryParse(entry.JellyfinUserId, out var linkedId))
        {
            var linked = _userManager.GetUserById(linkedId);
            if (linked is not null)
            {
                return linked;
            }
        }

        var preferredName = FirstNonEmpty(
            entry.JellyfinUserHint,
            entry.DisplayName,
            claims.Email?.Split('@')[0],
            config.UsernamePrefix + ShortHash(claims.GoogleSub));

        preferredName = SanitizeUsername(preferredName!);

        var existing = _userManager.GetUserByName(preferredName);
        if (existing is not null)
        {
            return existing;
        }

        // Prefer an exact prior username from the prefix+hash scheme.
        var hashed = SanitizeUsername(config.UsernamePrefix + ShortHash(claims.GoogleSub));
        existing = _userManager.GetUserByName(hashed);
        if (existing is not null)
        {
            return existing;
        }

        if (!config.CreateMissingUsers)
        {
            throw new InvalidOperationException(
                $"No Jellyfin user linked for Google sub {claims.GoogleSub} and CreateMissingUsers is false");
        }

        var username = EnsureUniqueUsername(preferredName);

        _logger.LogInformation(
            "Creating Jellyfin user {Username} for Google sub {GoogleSub}",
            username,
            claims.GoogleSub);

        var user = await _userManager.CreateUserAsync(username).ConfigureAwait(false);
        return user;
    }

    private string EnsureUniqueUsername(string baseName)
    {
        var candidate = baseName;
        var i = 1;
        while (_userManager.GetUserByName(candidate) is not null)
        {
            candidate = $"{baseName}-{i}";
            i++;
            if (i > 100)
            {
                throw new InvalidOperationException("Unable to allocate a unique Jellyfin username");
            }
        }

        return candidate;
    }

    private static string SanitizeUsername(string raw)
    {
        var cleaned = SafeName.Replace(raw.Trim(), "-").Trim('-', '.', '_');
        if (string.IsNullOrWhiteSpace(cleaned))
        {
            cleaned = "soup-user";
        }

        if (cleaned.Length > 64)
        {
            cleaned = cleaned[..64];
        }

        return cleaned;
    }

    private static string ShortHash(string value)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(value));
        return Convert.ToHexString(hash)[..10].ToLowerInvariant();
    }

    private static string? FirstNonEmpty(params string?[] values)
        => values.FirstOrDefault(v => !string.IsNullOrWhiteSpace(v));
}
