# Regenerate Dart protobuf files from protos/mesh_protocol.proto.
#
# Requirements:
#   protoc        >= 26  (winget install Google.Protobuf)
#   protoc_plugin == 21.1.2  (dart pub global activate protoc_plugin 21.1.2)
#
# Why pin 21.1.2:
#   This project uses `protobuf: ^3.1.0`. protoc_plugin 25.x emits the
#   shorthand `aD()/aI()/aE()` BuilderInfo helpers (protobuf 4.x API),
#   which do not exist in 3.1.0. 21.1.2 emits the long-form
#   `a<$core.double>(..., $pb.PbFieldType.OD)` style that 3.1.0 supports.
#
# What this script does:
#   1. Generates pb.dart / pbenum.dart / pbjson.dart / pbserver.dart into a
#      temporary directory.
#   2. Copies ONLY pb.dart and pbenum.dart into lib/app/proto/. We do not
#      use the JSON/server descriptors and keeping them out of the tree
#      means `git status` stays clean after every regen.
#   3. Project-defined constants (e.g. HandshakeSchema.currentSchemaVersion)
#      live in hand-written companion files such as
#      `lib/app/proto/handshake_schema.dart`, so they are NOT touched here.
#
# Usage (from anywhere — paths are resolved relative to this script):
#   pwsh resqmesh_app/scripts/gen_proto.ps1
#   # or
#   powershell -ExecutionPolicy Bypass -File resqmesh_app/scripts/gen_proto.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$AppDir    = Split-Path -Parent $PSScriptRoot
$ProtoDir  = Join-Path $AppDir 'protos'
$OutDir    = Join-Path $AppDir 'lib\app\proto'
$ProtoFile = 'mesh_protocol.proto'

# ── locate protoc ──────────────────────────────────────────────────────────────
$ProtocCmd = Get-Command protoc -ErrorAction SilentlyContinue
if ($ProtocCmd) {
    $Protoc = $ProtocCmd.Source
} else {
    $WinGetProtoc = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Google.Protobuf_Microsoft.Winget.Source_8wekyb3d8bbwe\bin\protoc.exe"
    if (Test-Path $WinGetProtoc) {
        $Protoc = $WinGetProtoc
    } else {
        Write-Error "protoc not found. Install via: winget install Google.Protobuf"
        exit 1
    }
}

# ── locate protoc-gen-dart ─────────────────────────────────────────────────────
$DartPlugin = Get-Command protoc-gen-dart -ErrorAction SilentlyContinue
if ($DartPlugin) {
    $Plugin = $DartPlugin.Source
} else {
    $CacheBat = "$env:LOCALAPPDATA\Pub\Cache\bin\protoc-gen-dart.bat"
    if (Test-Path $CacheBat) {
        $Plugin = $CacheBat
    } else {
        Write-Error "protoc-gen-dart not found.`nRun: dart pub global activate protoc_plugin 21.1.2"
        exit 1
    }
}

# ── verify plugin version ──────────────────────────────────────────────────────
$InstalledLine = (dart pub global list 2>$null | Select-String 'protoc_plugin')
if ($InstalledLine) {
    $InstalledVersion = $InstalledLine.ToString() -replace '.*protoc_plugin\s+', ''
    if ($InstalledVersion -ne '21.1.2') {
        Write-Warning "protoc_plugin $InstalledVersion detected; expected 21.1.2."
        Write-Warning "Run: dart pub global activate protoc_plugin 21.1.2"
    }
} else {
    Write-Warning "Could not verify protoc_plugin version (not in 'dart pub global list')."
}

# ── prepare temp output dir ───────────────────────────────────────────────────
$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "resqmesh_protogen_$([System.Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

try {
    # protoc on Windows requires forward slashes for --dart_out / --proto_path.
    $TmpDirFwd   = $TmpDir   -replace '\\', '/'
    $ProtoDirFwd = $ProtoDir -replace '\\', '/'

    Write-Host "Generating $ProtoFile -> $TmpDir (temp)"
    & $Protoc `
        "--dart_out=$TmpDirFwd" `
        "--plugin=protoc-gen-dart=$Plugin" `
        "--proto_path=$ProtoDirFwd" `
        "$ProtoDirFwd/$ProtoFile"

    if ($LASTEXITCODE -ne 0) {
        throw "protoc exited with code $LASTEXITCODE"
    }

    # ── copy ONLY the files we ship ───────────────────────────────────────────
    # We deliberately drop pbjson.dart / pbserver.dart — nothing imports them
    # and keeping them out of the tree means `git status` stays clean.
    $Keep = @('mesh_protocol.pb.dart', 'mesh_protocol.pbenum.dart')
    foreach ($f in $Keep) {
        $src = Join-Path $TmpDir $f
        if (-not (Test-Path $src)) {
            throw "Expected $f was not produced by protoc."
        }
        Copy-Item -Force $src (Join-Path $OutDir $f)
        Write-Host "  -> $OutDir\$f"
    }
} finally {
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Done. Generated files are pure codegen output."
Write-Host "Project constants (e.g. HandshakeSchema.currentSchemaVersion) live in"
Write-Host "lib/app/proto/handshake_schema.dart and are unaffected by this script."
