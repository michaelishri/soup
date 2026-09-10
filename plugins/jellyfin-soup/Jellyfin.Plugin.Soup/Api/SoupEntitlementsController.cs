using Jellyfin.Plugin.Soup.Api.Models;
using Jellyfin.Plugin.Soup.Configuration;
using Jellyfin.Plugin.Soup.Services;
using MediaBrowser.Common.Api;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace Jellyfin.Plugin.Soup.Api;

/// <summary>
/// Admin APIs for Soup server registration and entitlement invite/revoke.
/// </summary>
[ApiController]
[Route("SoupAuth")]
[Authorize(Policy = Policies.RequiresElevation)]
public sealed class SoupEntitlementsController : ControllerBase
{
    private readonly EntitlementService _entitlementService;
    private readonly ILogger<SoupEntitlementsController> _logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="SoupEntitlementsController"/> class.
    /// </summary>
    /// <param name="entitlementService">Entitlement service.</param>
    /// <param name="logger">Logger.</param>
    public SoupEntitlementsController(
        EntitlementService entitlementService,
        ILogger<SoupEntitlementsController> logger)
    {
        _entitlementService = entitlementService;
        _logger = logger;
    }

    /// <summary>
    /// List local entitlements (Pending + Active).
    /// </summary>
    /// <returns>Entitlement rows.</returns>
    [HttpGet("Entitlements")]
    [ProducesResponseType(typeof(IReadOnlyList<EntitlementEntry>), StatusCodes.Status200OK)]
    public ActionResult<IReadOnlyList<EntitlementEntry>> ListEntitlements()
        => Ok(_entitlementService.List());

    /// <summary>
    /// Invite by Google sub and/or email. Email-only stays Pending until sub is known.
    /// </summary>
    /// <param name="request">Invite payload.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Created or updated entitlement.</returns>
    [HttpPost("Entitlements/Invite")]
    [ProducesResponseType(typeof(EntitlementEntry), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<EntitlementEntry>> Invite(
        [FromBody] InviteRequest request,
        CancellationToken cancellationToken)
    {
        if (request is null
            || (string.IsNullOrWhiteSpace(request.GoogleSub) && string.IsNullOrWhiteSpace(request.Email)))
        {
            return BadRequest(new { error = "bad_request", message = "googleSub or email is required" });
        }

        try
        {
            var entry = await _entitlementService.InviteAsync(
                    request.GoogleSub,
                    request.Email,
                    request.DisplayName,
                    request.JellyfinUserHint,
                    cancellationToken)
                .ConfigureAwait(false);
            return Ok(entry);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Invite failed");
            return BadRequest(new
            {
                error = "invite_failed",
                message = SecretRedactor.Redact(ex.Message)
            });
        }
    }

    /// <summary>
    /// Revoke by local id or Google sub (also DELETEs on Soup when sub is known).
    /// </summary>
    /// <param name="idOrGoogleSub">Local entitlement id or Google sub.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>No content when revoked.</returns>
    [HttpDelete("Entitlements/{idOrGoogleSub}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Revoke(
        [FromRoute] string idOrGoogleSub,
        CancellationToken cancellationToken)
    {
        var ok = await _entitlementService.RevokeAsync(idOrGoogleSub, cancellationToken).ConfigureAwait(false);
        if (!ok)
        {
            return NotFound(new { error = "not_found", message = "Entitlement not found" });
        }

        return NoContent();
    }

    /// <summary>
    /// PUT server registration to Soup using plugin config.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>OK when registered.</returns>
    [HttpPost("RegisterServer")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> RegisterServer(CancellationToken cancellationToken)
    {
        try
        {
            await _entitlementService.RegisterServerAsync(cancellationToken).ConfigureAwait(false);
            return Ok(new { ok = true });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "RegisterServer failed");
            return BadRequest(new { error = "register_failed", message = SecretRedactor.Redact(ex.Message) });
        }
    }

    /// <summary>
    /// Register server and upsert all Active entitlements to Soup.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Sync count.</returns>
    [HttpPost("Sync")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> Sync(CancellationToken cancellationToken)
    {
        try
        {
            var count = await _entitlementService.SyncAllAsync(cancellationToken).ConfigureAwait(false);
            return Ok(new { ok = true, synced = count });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Sync failed");
            return BadRequest(new { error = "sync_failed", message = SecretRedactor.Redact(ex.Message) });
        }
    }

    /// <summary>
    /// Mint a Tailscale auth key and deposit it as a Soup transport grant (remint).
    /// </summary>
    /// <param name="idOrGoogleSub">Local entitlement id or Google sub.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>Updated entitlement.</returns>
    [HttpPost("Entitlements/{idOrGoogleSub}/TransportGrant")]
    [ProducesResponseType(typeof(EntitlementEntry), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<EntitlementEntry>> DepositTransportGrant(
        [FromRoute] string idOrGoogleSub,
        CancellationToken cancellationToken)
    {
        try
        {
            var entry = await _entitlementService
                .DepositTransportGrantAsync(idOrGoogleSub, cancellationToken)
                .ConfigureAwait(false);
            return Ok(entry);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("not found", StringComparison.OrdinalIgnoreCase))
        {
            return NotFound(new { error = "not_found", message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Transport grant deposit failed");
            return BadRequest(new
            {
                error = "transport_grant_failed",
                message = SecretRedactor.Redact(ex.Message)
            });
        }
    }
}
