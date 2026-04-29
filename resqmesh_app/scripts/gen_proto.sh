#!/usr/bin/env bash
# Regenerate Dart protobuf files from protos/mesh_protocol.proto.
#
# Requirements:
#   protoc        >= 26  (https://github.com/protocolbuffers/protobuf/releases)
#   protoc_plugin == 21.1.2  (dart pub global activate protoc_plugin 21.1.2)
#
# Why pin 21.1.2:
#   This project uses `protobuf: ^3.1.0`. protoc_plugin 25.x emits the
#   shorthand aD()/aI()/aE() BuilderInfo helpers (protobuf 4.x API), which
#   do not exist in 3.1.0. 21.1.2 emits the long-form a<$core.double>(...,
#   $pb.PbFieldType.OD) style that 3.1.0 supports.
#
# What this script does:
#   1. Generates pb.dart / pbenum.dart / pbjson.dart / pbserver.dart into a
#      temporary directory.
#   2. Copies ONLY pb.dart and pbenum.dart into lib/app/proto/. We do not
#      use the JSON/server descriptors and keeping them out of the tree
#      means `git status` stays clean after every regen.
#   3. Project-defined constants (e.g. HandshakeSchema.currentSchemaVersion)
#      live in hand-written companion files such as
#      lib/app/proto/handshake_schema.dart, so they are NOT touched here.
#
# Usage (from anywhere — paths are resolved relative to this script):
#   bash resqmesh_app/scripts/gen_proto.sh
#
# Note for Windows users: this bash script is intended for Unix / CI shells.
# On Windows use `scripts/gen_proto.ps1` instead — running this .sh under
# WSL when protoc lives in a WinGet path generally fails.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROTO_DIR="$APP_DIR/protos"
OUT_DIR="$APP_DIR/lib/app/proto"
PROTO_FILE="mesh_protocol.proto"

# ── locate protoc ──────────────────────────────────────────────────────────────
if command -v protoc &>/dev/null; then
  PROTOC="protoc"
else
  # Windows WinGet install path (best-effort fallback when running under MSYS/WSL).
  WINGET_PROTOC="${LOCALAPPDATA:-}/Microsoft/WinGet/Packages/Google.Protobuf_Microsoft.Winget.Source_8wekyb3d8bbwe/bin/protoc.exe"
  if [[ -n "${LOCALAPPDATA:-}" && -f "$WINGET_PROTOC" ]]; then
    PROTOC="$WINGET_PROTOC"
  else
    echo "ERROR: protoc not found. Install via package manager or add to PATH." >&2
    exit 1
  fi
fi

# ── locate protoc-gen-dart ─────────────────────────────────────────────────────
if command -v protoc-gen-dart &>/dev/null; then
  PLUGIN="protoc-gen-dart"
elif [[ -n "${LOCALAPPDATA:-}" && -f "$LOCALAPPDATA/Pub/Cache/bin/protoc-gen-dart.bat" ]]; then
  PLUGIN="$LOCALAPPDATA/Pub/Cache/bin/protoc-gen-dart.bat"
else
  echo "ERROR: protoc-gen-dart not found." >&2
  echo "  Run: dart pub global activate protoc_plugin 21.1.2" >&2
  exit 1
fi

# ── verify plugin version ──────────────────────────────────────────────────────
INSTALLED_VERSION=$(dart pub global list 2>/dev/null | awk '/protoc_plugin/ {print $2}')
if [[ -n "$INSTALLED_VERSION" && "$INSTALLED_VERSION" != "21.1.2" ]]; then
  echo "WARNING: protoc_plugin $INSTALLED_VERSION detected; expected 21.1.2." >&2
  echo "  Run: dart pub global activate protoc_plugin 21.1.2" >&2
fi

# ── prepare temp output dir ───────────────────────────────────────────────────
TMP_DIR="$(mktemp -d -t resqmesh_protogen.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Generating $PROTO_FILE -> $TMP_DIR (temp)"
"$PROTOC" \
  --dart_out="$TMP_DIR" \
  --plugin="protoc-gen-dart=$PLUGIN" \
  --proto_path="$PROTO_DIR" \
  "$PROTO_DIR/$PROTO_FILE"

# ── copy ONLY the files we ship ───────────────────────────────────────────────
# We deliberately drop pbjson.dart / pbserver.dart — nothing imports them
# and keeping them out of the tree means `git status` stays clean.
for f in mesh_protocol.pb.dart mesh_protocol.pbenum.dart; do
  if [[ ! -f "$TMP_DIR/$f" ]]; then
    echo "ERROR: Expected $f was not produced by protoc." >&2
    exit 1
  fi
  cp -f "$TMP_DIR/$f" "$OUT_DIR/$f"
  echo "  -> $OUT_DIR/$f"
done

echo ""
echo "Done. Generated files are pure codegen output."
echo "Project constants (e.g. HandshakeSchema.currentSchemaVersion) live in"
echo "lib/app/proto/handshake_schema.dart and are unaffected by this script."
