import 'dart:math';

void main() {
  final rng = Random();
  print('=== MediRecord License Key Generator ===');
  print('');

  final count = 100;
  for (int i = 1; i <= count; i++) {
    final key = _generateKey(rng);
    final formatted = '${key.substring(0, 5)}-${key.substring(5, 10)}-${key.substring(10, 15)}-${key.substring(15, 20)}';
    print('Key #${i.toString().padLeft(3, '0')}:  $formatted');
  }

  print('');
  print('=== Validation rules (hidden from users) ===');
  print('Format: XXXXX-XXXXX-XXXXX-XXXXX');
  print('Char sum mod 7 == 0');
  print('Char[4] == Char[9]');
  print('Char[14] == Char[19]');
  print('Only A-Z and 0-9');
}

String _generateKey(Random rng) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  while (true) {
    final buf = StringBuffer();
    for (int i = 0; i < 20; i++) {
      buf.write(chars[rng.nextInt(chars.length)]);
    }
    final key = buf.toString();
    // Enforce match rules: positions 4==9 and 14==19
    final finalKey = key.substring(0, 4) +
        key[4] + // pos 4
        key.substring(5, 9) +
        key[4] + // pos 9 same as pos 4
        key.substring(10, 14) +
        key[14] + // pos 14
        key.substring(15, 19) +
        key[14]; // pos 19 same as pos 14

    // Check sum mod 7
    int sum = 0;
    for (int i = 0; i < finalKey.length; i++) {
      sum += finalKey.codeUnitAt(i);
    }
    if (sum % 7 == 0) return finalKey;
  }
}
