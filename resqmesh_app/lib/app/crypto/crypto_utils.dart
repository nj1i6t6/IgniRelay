/// Shared cryptographic utilities
/// Extracted from EventManager and MeshEventHandler to eliminate duplication
library;

/// Constant-time-ish byte array comparison for public key verification
bool bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
