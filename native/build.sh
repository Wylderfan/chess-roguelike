#!/usr/bin/env sh
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
rid=${1:-linux-x64}
dotnet publish "$base/engine/Chess-Coding-Adventure.csproj" -c Release -r "$rid" --self-contained true -p:PublishSingleFile=true -p:DebugType=None -o "$base/bin/$rid"
