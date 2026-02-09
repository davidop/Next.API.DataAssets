using System.Text.RegularExpressions;

namespace Next.API.DataAssets.Security;

public static class AssetPathSanitizer
{
    // Allow simple filenames with dots, dashes, underscores. No slashes, no backslashes.
    private static readonly Regex Allowed = new(@"^[A-Za-z0-9][A-Za-z0-9._-]{0,255}$", RegexOptions.Compiled);

    public static bool TrySanitizeFileName(string? input, out string safe, out string reason)
    {
        safe = string.Empty;
        reason = string.Empty;

        if (string.IsNullOrWhiteSpace(input))
        {
            reason = "Filename is required.";
            return false;
        }

        // Normalize and block path separators
        if (input.Contains('/') || input.Contains('\\'))
        {
            reason = "Path separators are not allowed.";
            return false;
        }

        // Block traversal patterns
        if (input.Contains("..", StringComparison.Ordinal))
        {
            reason = "Path traversal is not allowed.";
            return false;
        }

        // Block leading/trailing whitespace
        var trimmed = input.Trim();
        if (!string.Equals(trimmed, input, StringComparison.Ordinal))
        {
            reason = "Leading/trailing whitespace is not allowed.";
            return false;
        }

        if (!Allowed.IsMatch(trimmed))
        {
            reason = "Filename contains invalid characters.";
            return false;
        }

        safe = trimmed;
        return true;
    }
}
