$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

dotnet run `
  --project (Join-Path $ProjectRoot "tests/MyCodexMeter.Core.SelfTests/MyCodexMeter.Core.SelfTests.csproj") `
  -c Release
