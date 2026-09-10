using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Soup.Services;

/// <summary>
/// Verifies Soup Pattern A assertion JWTs against Soup JWKS.
/// </summary>
public sealed class AssertionVerifier
{
    private readonly SoupApiClient _soupApiClient;
    private readonly ILogger<AssertionVerifier> _logger;
    private readonly SemaphoreSlim _cacheLock = new(1, 1);
    private string? _cachedJwks;
    private DateTimeOffset _cachedUntil = DateTimeOffset.MinValue;

    /// <summary>
    /// Initializes a new instance of the <see cref="AssertionVerifier"/> class.
    /// </summary>
    /// <param name="soupApiClient">Soup API client.</param>
    /// <param name="logger">Logger.</param>
    public AssertionVerifier(SoupApiClient soupApiClient, ILogger<AssertionVerifier> logger)
    {
        _soupApiClient = soupApiClient;
        _logger = logger;
    }

    /// <summary>
    /// Validate a compact JWT assertion and return subject claims.
    /// </summary>
    /// <param name="assertion">Compact JWT from Soup <c>POST /v1/assertions</c>.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Validated subject.</returns>
    public async Task<AssertionClaims> VerifyAsync(string assertion, CancellationToken cancellationToken = default)
    {
        var config = Plugin.Instance?.Configuration
            ?? throw new InvalidOperationException("Soup plugin is not loaded");

        var jwksJson = await GetJwksCachedAsync(cancellationToken).ConfigureAwait(false);
        var jwks = new JsonWebKeySet(jwksJson);
        var signingKeys = jwks.GetSigningKeys().ToList();
        if (signingKeys.Count == 0)
        {
            // Microsoft.IdentityModel does not convert OKP/Ed25519 JWKs via GetSigningKeys().
            // Prefer RS256 (or ES*) for Soup Identity so plugin verification works.
            var okp = jwks.Keys.Any(k =>
                string.Equals(k.Kty, "OKP", StringComparison.OrdinalIgnoreCase));
            if (okp)
            {
                throw new SecurityTokenException(
                    "Soup JWKS is EdDSA/OKP; this plugin needs RS256 (set JWT_ALG=RS256 on Soup Identity).");
            }

            signingKeys = jwks.Keys.Cast<SecurityKey>().ToList();
            if (signingKeys.Count == 0)
            {
                throw new SecurityTokenException("Soup JWKS contained no usable signing keys");
            }
        }

        var parameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = config.AssertionIssuer,
            ValidateAudience = true,
            ValidAudience = config.Audience,
            ValidateLifetime = true,
            RequireExpirationTime = true,
            ValidateIssuerSigningKey = true,
            IssuerSigningKeys = signingKeys,
            ClockSkew = TimeSpan.FromMinutes(1)
        };

        var handler = new JsonWebTokenHandler();
        var result = await handler.ValidateTokenAsync(assertion, parameters).ConfigureAwait(false);
        if (!result.IsValid || result.SecurityToken is not JsonWebToken token)
        {
            var reason = result.Exception?.Message ?? "invalid token";
            _logger.LogWarning("Soup assertion rejected: {Reason}", reason);
            throw new SecurityTokenException("Invalid Soup assertion: " + reason);
        }

        if (!token.TryGetPayloadValue<string>("typ", out var typ)
            || !string.Equals(typ, "soup_assertion", StringComparison.Ordinal))
        {
            throw new SecurityTokenException("JWT typ must be soup_assertion");
        }

        var email = token.Subject;
        if (string.IsNullOrWhiteSpace(email))
        {
            token.TryGetPayloadValue<string>("email", out email);
        }

        if (string.IsNullOrWhiteSpace(email) || !email.Contains('@', StringComparison.Ordinal))
        {
            throw new SecurityTokenException("Assertion missing email subject");
        }

        email = email.Trim().ToLowerInvariant();
        token.TryGetPayloadValue<string>("server_id", out var serverId);

        if (!string.IsNullOrWhiteSpace(serverId)
            && !string.Equals(serverId, config.ServerId, StringComparison.Ordinal))
        {
            throw new SecurityTokenException("Assertion server_id does not match this plugin");
        }

        return new AssertionClaims(email, serverId);
    }

    private async Task<string> GetJwksCachedAsync(CancellationToken cancellationToken)
    {
        await _cacheLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_cachedJwks is not null && DateTimeOffset.UtcNow < _cachedUntil)
            {
                return _cachedJwks;
            }

            _cachedJwks = await _soupApiClient.FetchJwksAsync(cancellationToken).ConfigureAwait(false);
            _cachedUntil = DateTimeOffset.UtcNow.AddMinutes(10);
            return _cachedJwks;
        }
        finally
        {
            _cacheLock.Release();
        }
    }
}

/// <summary>
/// Claims extracted from a verified Soup assertion.
/// </summary>
/// <param name="Email">Google account email (JWT <c>sub</c>).</param>
/// <param name="ServerId">Optional server_id claim.</param>
public sealed record AssertionClaims(string Email, string? ServerId);
