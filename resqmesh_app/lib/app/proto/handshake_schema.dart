// handshake_schema.dart
//
// Hand-written companion to the generated `mesh_protocol.pb.dart`. Keeps
// project-defined constants OUT of the generated file so codegen can be
// re-run safely (see scripts/gen_proto.ps1 / gen_proto.sh).
//
// Why this file exists:
//   The HandshakeCompleteData wire format adds an `optional int32
//   schema_version` field (tag 10). The numeric value of "current schema"
//   is project policy, not part of the .proto wire spec — protoc cannot
//   produce it. Putting it here means a fresh codegen run never wipes it.
//
// Usage:
//   import 'package:ignirelay_app/app/proto/handshake_schema.dart';
//   ...
//   schemaVersion: HandshakeSchema.currentSchemaVersion,

/// Project-level constants for HandshakeCompleteData.schema_version.
///
/// Bump `currentSchemaVersion` whenever the meaning of any field in
/// HandshakeCompleteData changes in a way old peers must reject. Adding
/// new optional fields does NOT require a bump (proto3 unknown-field
/// handling already covers forward/backward compat).
class HandshakeSchema {
  HandshakeSchema._();

  /// Current wire-format version written by this build.
  ///
  /// Old peers that don't know about `schema_version` will see the field
  /// as unknown and ignore it (proto3 unknown-field semantics). New peers
  /// reading payloads from old peers see `schemaVersion == 0` (proto3
  /// scalar default) and `hasSchemaVersion() == false`.
  static const int currentSchemaVersion = 1;
}
