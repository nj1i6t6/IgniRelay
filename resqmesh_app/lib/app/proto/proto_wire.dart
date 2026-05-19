// Hand-written proto3 wire-format primitives (v0.3 Stage 0c second wave).
//
// Spec: https://protobuf.dev/programming-guides/encoding/
//
// Why hand-coded? `protoc` is not run in this stage; the v0.3 EventEnvelope v2
// wire shape is small and frozen by the spec, so a hand-written codec gives
// bit-identical control across Dart/Kotlin/Swift without depending on the
// generated `*.pb.dart`. The canonical signature input (lib/app/crypto/
// canonical_encoder_v2.dart) is intentionally NOT proto3 — it is the spec-
// defined byte sequence used as the Ed25519 input.
//
// Supported wire types:
//   0  varint     (uint32, uint64, int32, int64, bool, enum)
//   2  length-delimited (string, bytes, embedded message)
//
// Not supported (not used by EventEnvelope v2):
//   1  64-bit fixed
//   5  32-bit fixed
//   3/4 group (deprecated)
//
// Decoder rules:
//   - Unknown fields are skipped (forward compat).
//   - Duplicate fields: last value wins (proto3 norm).
//   - Default values are NOT emitted on encode (proto3 norm).

import 'dart:convert';
import 'dart:typed_data';

const int wireVarint = 0;
const int wireLengthDelimited = 2;

/// proto3 tag = (field_number << 3) | wire_type.
int makeTag(int fieldNumber, int wireType) => (fieldNumber << 3) | wireType;

/// Mutable byte builder for encoding.
class ProtoWriter {
  final BytesBuilder _bb = BytesBuilder(copy: false);

  Uint8List toBytes() => _bb.toBytes();

  int get length => _bb.length;

  void writeTag(int fieldNumber, int wireType) {
    writeVarint(makeTag(fieldNumber, wireType));
  }

  /// Encode an unsigned varint (up to 64 bits).
  void writeVarint(int value) {
    // Dart `int` is 64-bit signed on the VM and on web is double-backed; for
    // our values (timestamps + small ints) the unsigned-style encoding below
    // is correct for both platforms.
    var v = value;
    while ((v & ~0x7F) != 0) {
      _bb.addByte((v & 0x7F) | 0x80);
      v = v >>> 7;
    }
    _bb.addByte(v & 0x7F);
  }

  void writeUint32(int fieldNumber, int value) {
    if (value == 0) return; // proto3 default omitted
    writeTag(fieldNumber, wireVarint);
    writeVarint(value);
  }

  void writeUint64(int fieldNumber, int value) {
    if (value == 0) return;
    writeTag(fieldNumber, wireVarint);
    writeVarint(value);
  }

  void writeBool(int fieldNumber, bool value) {
    if (!value) return; // proto3 default omitted
    writeTag(fieldNumber, wireVarint);
    writeVarint(1);
  }

  void writeEnum(int fieldNumber, int value) {
    if (value == 0) return; // proto3 enum default == 0
    writeTag(fieldNumber, wireVarint);
    writeVarint(value);
  }

  void writeBytes(int fieldNumber, List<int> bytes) {
    if (bytes.isEmpty) return;
    writeTag(fieldNumber, wireLengthDelimited);
    writeVarint(bytes.length);
    _bb.add(bytes);
  }

  /// Like [writeBytes] but emits the tag + length-prefix EVEN when [bytes]
  /// is empty. Used by EventEnvelopeV2.encode for the `payload` field, which
  /// envelope_v2_spec §3.4 lists as a required field — the v0.3 decoder
  /// distinguishes "payload field absent on wire" (throw) from "payload field
  /// present with zero bytes" (allowed for event types that carry no payload,
  /// e.g. HEARTBEAT). Standard proto3 would default-omit; this helper makes
  /// the v0.3 spec semantics representable on the wire.
  void writeBytesAlways(int fieldNumber, List<int> bytes) {
    writeTag(fieldNumber, wireLengthDelimited);
    writeVarint(bytes.length);
    if (bytes.isNotEmpty) _bb.add(bytes);
  }

  void writeString(int fieldNumber, String value) {
    if (value.isEmpty) return;
    final bytes = utf8.encode(value);
    writeTag(fieldNumber, wireLengthDelimited);
    writeVarint(bytes.length);
    _bb.add(bytes);
  }

  /// Embedded message — value is its serialized bytes.
  void writeMessage(int fieldNumber, Uint8List value) {
    writeTag(fieldNumber, wireLengthDelimited);
    writeVarint(value.length);
    _bb.add(value);
  }

  /// Repeated bytes (one length-delimited field per element).
  void writeRepeatedBytes(int fieldNumber, List<List<int>> elements) {
    for (final e in elements) {
      writeBytes(fieldNumber, e);
    }
  }

  /// Repeated string (one length-delimited field per element).
  void writeRepeatedString(int fieldNumber, List<String> elements) {
    for (final s in elements) {
      writeString(fieldNumber, s);
    }
  }

  /// Repeated embedded message (one length-delimited field per element).
  void writeRepeatedMessage(int fieldNumber, List<Uint8List> elements) {
    for (final m in elements) {
      writeMessage(fieldNumber, m);
    }
  }
}

/// Streaming reader over a proto3 byte buffer.
class ProtoReader {
  final Uint8List _data;
  int _pos = 0;

  ProtoReader(this._data);

  bool get isAtEnd => _pos >= _data.length;

  int get position => _pos;

  /// Read the next field tag. Returns -1 when EOF.
  int readTag() {
    if (isAtEnd) return -1;
    return readVarint();
  }

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_pos >= _data.length) {
        throw ProtoDecodeException('truncated varint at offset $_pos');
      }
      final b = _data[_pos++];
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) return result;
      shift += 7;
      if (shift > 63) {
        throw ProtoDecodeException('varint > 64 bits at offset $_pos');
      }
    }
  }

  bool readBool() => readVarint() != 0;

  int readUint32() => readVarint();

  int readUint64() => readVarint();

  /// Length-delimited bytes; returns a view into the underlying buffer.
  Uint8List readLengthDelimited() {
    final len = readVarint();
    if (len < 0 || _pos + len > _data.length) {
      throw ProtoDecodeException(
          'length-delimited overflow at offset $_pos (len=$len, remaining=${_data.length - _pos})');
    }
    final out = Uint8List.sublistView(_data, _pos, _pos + len);
    _pos += len;
    return out;
  }

  String readString() => utf8.decode(readLengthDelimited());

  /// Skip the value of an unknown field given its wire type.
  void skipValue(int wireType) {
    switch (wireType) {
      case wireVarint:
        readVarint();
        break;
      case wireLengthDelimited:
        final len = readVarint();
        if (_pos + len > _data.length) {
          throw ProtoDecodeException('skip length-delimited overflow');
        }
        _pos += len;
        break;
      case 1: // 64-bit fixed
        if (_pos + 8 > _data.length) throw ProtoDecodeException('skip 64-bit truncated');
        _pos += 8;
        break;
      case 5: // 32-bit fixed
        if (_pos + 4 > _data.length) throw ProtoDecodeException('skip 32-bit truncated');
        _pos += 4;
        break;
      default:
        throw ProtoDecodeException('unsupported wire type $wireType');
    }
  }
}

/// Helpers for decoding tag + wire type.
int tagFieldNumber(int tag) => tag >> 3;
int tagWireType(int tag) => tag & 0x7;

class ProtoDecodeException implements Exception {
  final String message;
  ProtoDecodeException(this.message);
  @override
  String toString() => 'ProtoDecodeException: $message';
}
