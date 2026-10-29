param([string]$Runtime = "win-x64")
$ErrorActionPreference = "Stop"
# Install the official .NET 10 SDK first. No Godot .NET build is required.
$project = Join-Path $PSScriptRoot "engine/Chess-Coding-Adventure.csproj"
$out = Join-Path $PSScriptRoot "bin/$Runtime"
dotnet publish $project -c Release -r $Runtime --self-contained true -p:PublishSingleFile=true -p:DebugType=None -o $out
if ($LASTEXITCODE -ne 0) { throw "Engine build failed" }
Write-Host "Built $out"
