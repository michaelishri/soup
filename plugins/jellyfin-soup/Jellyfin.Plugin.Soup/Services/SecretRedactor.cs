using System.Text.RegularExpressions;

namespace Jellyfin.Plugin.Soup.Services;

/// <summary>
/// Redacts auth keys and tokens from log / exception text (Wave 4).
/// </summary>
internal static partial class SecretRedactor
{
    [GeneratedRegex(@"tskey-(?:auth|api|client)-[A-Za-z0-9_-]+", RegexOptions.IgnoreCase)]
    private static partial Regex TsKeyRegex();

    [GeneratedRegex(@"Bearer\s+[A-Za-z0-9._~+/=-]+", RegexOptions.IgnoreCase)]
    private static partial Regex BearerRegex();

    [GeneratedRegex(@"""(?:access_token|refresh_token|material|client_secret|plugin_secret)""\s*:\s*""[^""]*""", RegexOptions.IgnoreCase)]
    private static partial Regex JsonSecretRegex();

    [GeneratedRegex(@"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+")]
    private static partial Regex JwtRegex();

    /// <summary>
    /// Replace secret-shaped substrings with <c>[redacted]</c>.
    /// </summary>
    /// <param name="input">Raw log or exception text.</param>
    /// <returns>Redacted text.</returns>
    public static string Redact(string? input)
    {
        if (string.IsNullOrEmpty(input))
        {
            return input ?? string.Empty;
        }

        var outText = TsKeyRegex().Replace(input, "[redacted]");
        outText = BearerRegex().Replace(outText, "[redacted]");
        outText = JsonSecretRegex().Replace(outText, "\"[redacted]\":\"[redacted]\"");
        outText = JwtRegex().Replace(outText, "[redacted]");
        return outText;
    }
}
