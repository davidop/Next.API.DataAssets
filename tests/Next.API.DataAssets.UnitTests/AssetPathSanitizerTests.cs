using Next.API.DataAssets.Security;
using Xunit;

namespace Next.API.DataAssets.UnitTests;

public class AssetPathSanitizerTests
{
    [Theory]
    [InlineData("DataAsset.csv")]
    [InlineData("report_2026-02-09.csv")]
    [InlineData("a.txt")]
    public void Valid_names_pass(string name)
    {
        var ok = AssetPathSanitizer.TrySanitizeFileName(name, out var safe, out var reason);
        Assert.True(ok, reason);
        Assert.Equal(name, safe);
    }

    [Theory]
    [InlineData("../secret.txt")]
    [InlineData("..\\secret.txt")]
    [InlineData("folder/file.txt")]
    [InlineData("folder\\file.txt")]
    [InlineData("   DataAsset.csv")]
    [InlineData("DataAsset.csv   ")]
    [InlineData("")]
    [InlineData(" ")]
    public void Invalid_names_fail(string name)
    {
        var ok = AssetPathSanitizer.TrySanitizeFileName(name, out _, out var reason);
        Assert.False(ok);
        Assert.False(string.IsNullOrWhiteSpace(reason));
    }
}
