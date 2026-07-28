$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$RepositoryRoot = Resolve-Path (Join-Path $ProjectRoot "..")
$RuntimeIdentifier = if ($args.Count -gt 0) { $args[0] } else { "win-x64" }
$OutputPath = Join-Path $RepositoryRoot "dist/windows-$RuntimeIdentifier"

dotnet publish `
  (Join-Path $ProjectRoot "src/MyCodexMeter.Windows/MyCodexMeter.Windows.csproj") `
  -c Release `
  -r $RuntimeIdentifier `
  --self-contained true `
  -p:PublishSingleFile=true `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -o $OutputPath

Write-Output $OutputPath
