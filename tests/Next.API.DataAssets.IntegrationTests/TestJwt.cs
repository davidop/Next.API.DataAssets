using Microsoft.IdentityModel.Tokens;
using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace Next.API.DataAssets.IntegrationTests;

public static class TestJwt
{
    public const string SigningKey = "TEST_SIGNING_KEY_32+_CHARS_LONG____";
    public static string CreateToken(string subject = "user-123")
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(SigningKey));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: "test",
            audience: "test",
            claims: new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, subject),
                new Claim("auth_method", "jwt")
            },
            notBefore: DateTime.UtcNow.AddMinutes(-1),
            expires: DateTime.UtcNow.AddMinutes(15),
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
