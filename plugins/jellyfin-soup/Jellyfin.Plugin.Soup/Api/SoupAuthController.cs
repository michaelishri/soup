using Jellyfin.Plugin.Soup.Api.Models;
using Jellyfin.Plugin.Soup.Services;
using MediaBrowser.Common.Extensions;
using MediaBrowser.Controller.Authentication;
using MediaBrowser.Controller.Session;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;

namespace Jellyfin.Plugin.Soup.Api;

/// <summary>
/// Pattern A exchange: Soup assertion JWT → Jellyfin <see cref="AuthenticationResult"/>.
/// </summary>
[ApiController]
[Route("SoupAuth")]
public sealed class SoupAuthController : ControllerBase
{
    private readonly AssertionVerifier _assertionVerifier;
    private readonly EntitlementService _entitlementService;
    private readonly UserLinkService _userLinkService;
    private readonly ISessionManager _sessionManager;
    private readonly ILogger<SoupAuthController> _logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="SoupAuthController"/> class.
    /// </summary>
    /// <param name="assertionVerifier">Assertion verifier.</param>
    /// <param name="entitlementService">Entitlement service.</param>
    /// <param name="userLinkService">User link service.</param>
    /// <param name="sessionManager">Session manager.</param>
    /// <param name="logger">Logger.</param>
    public SoupAuthController(
        AssertionVerifier assertionVerifier,
        EntitlementService entitlementService,
        UserLinkService userLinkService,
        ISessionManager sessionManager,
        ILogger<SoupAuthController> logger)
    {
        _assertionVerifier = assertionVerifier;
        _entitlementService = entitlementService;
        _userLinkService = userLinkService;
        _sessionManager = sessionManager;
        _logger = logger;
    }

    /// <summary>
    /// Exchange a Soup assertion for a Jellyfin session.
    /// </summary>
    /// <param name="request">Assertion plus device/app binding.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Standard Jellyfin authentication result.</returns>
    [HttpPost("Exchange")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(AuthenticationResult), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<AuthenticationResult>> Exchange(
        [FromBody] ExchangeRequest request,
        CancellationToken cancellationToken)
    {
        if (request is null
            || string.IsNullOrWhiteSpace(request.Assertion)
            || string.IsNullOrWhiteSpace(request.DeviceId)
            || string.IsNullOrWhiteSpace(request.DeviceName)
            || string.IsNullOrWhiteSpace(request.App)
            || string.IsNullOrWhiteSpace(request.AppVersion))
        {
            return BadRequest(new
            {
                error = "bad_request",
                message = "assertion, deviceId, deviceName, app, and appVersion are required"
            });
        }

        AssertionClaims claims;
        try
        {
            claims = await _assertionVerifier.VerifyAsync(request.Assertion, cancellationToken)
                .ConfigureAwait(false);
        }
        catch (SecurityTokenException ex)
        {
            _logger.LogWarning(ex, "Soup assertion verification failed");
            return Unauthorized(new { error = "invalid_assertion", message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Soup assertion verification error");
            return Unauthorized(new { error = "invalid_assertion", message = "Unable to verify assertion" });
        }

        var entitlement = await _entitlementService
            .ResolveForAssertionAsync(claims, cancellationToken)
            .ConfigureAwait(false);
        if (entitlement is null)
        {
            _logger.LogWarning("No local entitlement for Google email {Email}", claims.Email);
            return StatusCode(StatusCodes.Status403Forbidden, new
            {
                error = "not_entitled",
                message = "Google email is not invited on this Jellyfin server"
            });
        }

        var user = await _userLinkService.ResolveOrCreateAsync(entitlement, claims).ConfigureAwait(false);
        _entitlementService.AttachJellyfinUser(claims.Email, user.Id);

        var authRequest = new AuthenticationRequest
        {
            UserId = user.Id,
            Username = user.Username,
            App = request.App,
            AppVersion = request.AppVersion,
            DeviceId = request.DeviceId,
            DeviceName = request.DeviceName,
            RemoteEndPoint = HttpContext.GetNormalizedRemoteIP().ToString()
        };

        var result = await _sessionManager.AuthenticateDirect(authRequest).ConfigureAwait(false);
        return Ok(result);
    }
}
