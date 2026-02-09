# .NET 10.0 Upgrade Plan

## Execution Steps

Execute steps below sequentially one by one in the order they are listed.

1. Validate that an .NET 10.0 SDK required for this upgrade is installed on the machine and if not, help to get it installed.
2. Ensure that the SDK version specified in global.json files is compatible with the .NET 10.0 upgrade.
3. Upgrade `src\Next.API.DataAssets\Next.API.DataAssets.csproj`
4. Upgrade `tests\Next.API.DataAssets.IntegrationTests\Next.API.DataAssets.IntegrationTests.csproj`
5. Upgrade `tests\Next.API.DataAssets.UnitTests\Next.API.DataAssets.UnitTests.csproj`

## Settings

This section contains settings and data used by execution steps.

### Excluded projects

Table below contains projects that do belong to the dependency graph for selected projects and should not be included in the upgrade.

| Project name                                   | Description                 |
|:-----------------------------------------------|:---------------------------:|

### Aggregate NuGet packages modifications across all projects

NuGet packages used across all selected projects or their dependencies that need version update in projects that reference them.

| Package Name                                    | Current Version | New Version | Description                                                                 |
|:------------------------------------------------|:---------------:|:-----------:|:----------------------------------------------------------------------------|
| Microsoft.AspNetCore.Authentication.JwtBearer   |     8.0.2       |   10.0.2    | Replace with Microsoft.AspNetCore.Authentication.JwtBearer 10.0.2          |
| Microsoft.AspNetCore.Mvc.Testing                 |     8.0.2       |   10.0.2    | Recommended for test projects targeting .NET 10.0                          |
| Microsoft.AspNetCore.OpenApi                    |     8.0.2       |   10.0.2    | Replace with Microsoft.AspNetCore.OpenApi 10.0.2                           |
| Microsoft.Extensions.FileProviders.Physical     |     8.0.2       |   10.0.2    | Replace with Microsoft.Extensions.FileProviders.Physical 10.0.2            |
| Microsoft.IdentityModel.Tokens                 |     7.5.1       |   8.15.0    | Package is deprecated; move to latest stable IdentityModel LTS 8.15.0      |
| System.IdentityModel.Tokens.Jwt                 |     7.5.1       |   8.15.0    | Package is deprecated; move to latest stable IdentityModel LTS 8.15.0      |

### Project upgrade details
This section contains details about each project upgrade and modifications that need to be done in the project.

#### src\Next.API.DataAssets\Next.API.DataAssets.csproj modifications

Project properties changes:
  - Target framework should be changed from `net8.0` to `net10.0`

NuGet packages changes:
  - `Microsoft.AspNetCore.Authentication.JwtBearer` update from `8.0.2` to `10.0.2`
  - `Microsoft.AspNetCore.OpenApi` update from `8.0.2` to `10.0.2`
  - `Microsoft.Extensions.FileProviders.Physical` update from `8.0.2` to `10.0.2`
  - `Microsoft.IdentityModel.Tokens` update from `7.5.1` to `8.15.0` (deprecated -> use LTS)

Other changes:
  - Verify any breaking changes associated with Microsoft.IdentityModel and JwtBearer authentication APIs.

#### tests\Next.API.DataAssets.IntegrationTests\Next.API.DataAssets.IntegrationTests.csproj modifications

Project properties changes:
  - Target framework should be changed from `net8.0` to `net10.0`

NuGet packages changes:
  - `Microsoft.AspNetCore.Mvc.Testing` update from `8.0.2` to `10.0.2`
  - `Microsoft.IdentityModel.Tokens` update from `7.5.1` to `8.15.0`
  - `System.IdentityModel.Tokens.Jwt` update from `7.5.1` to `8.15.0`

Other changes:
  - Verify integration test host compatibility with ASP.NET Core 10.0 test hosting.

#### tests\Next.API.DataAssets.UnitTests\Next.API.DataAssets.UnitTests.csproj modifications

Project properties changes:
  - Target framework should be changed from `net8.0` to `net10.0`

NuGet packages changes:
  - No package changes detected for this project in analysis; update if build/test failures indicate required package updates.

