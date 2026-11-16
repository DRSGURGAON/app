import 'dart:math' as math;

import 'package:flutter/widgets.dart' show StringCharacters;

import 'backup_service.dart' show minBackupPasswordLength;

enum PasswordStrength { tooShort, weak, fair, strong }

/// Passwords people pick first. Checked case-insensitively, also with digits
/// and symbols stripped from the ends ("Password@123" -> "password").
const _common = {
  'password',
  'passw0rd',
  'qwerty',
  'qwertyuiop',
  'asdfghjkl',
  'zxcvbnm',
  'iloveyou',
  'welcome',
  'admin',
  'letmein',
  'monkey',
  'dragon',
  'sunshine',
  'princess',
  'football',
  'cricket',
  'baseball',
  'superman',
  'batman',
  'india',
  'bharat',
  'hindustan',
  'jaihind',
  'krishna',
  'ganesh',
  'shiva',
  'sairam',
  'omsairam',
  'jaishriram',
  'docsafe',
  'backup',
  'mobile',
  'abcdefgh',
  'abcd1234',
  'changeme',
  'secret',
  'computer',
  'internet',
};

const _sequences = [
  'abcdefghijklmnopqrstuvwxyz',
  '01234567890',
  'qwertyuiopasdfghjklzxcvbnm',
];

/// Offline estimate of how hard a backup password is to guess.
///
/// No dictionary download and nothing leaves the phone. Roughly: bits =
/// length x log2(character pool), with common passwords, keyboard/alphabet
/// runs, repeats and digit-only passwords (dates, phone numbers) marked weak.
/// The backup file uses PBKDF2, which slows guessing but cannot save a
/// password that is on every attacker's list.
PasswordStrength passwordStrength(String password) {
  final chars = password.characters.toList();
  if (chars.length < minBackupPasswordLength) return PasswordStrength.tooShort;

  final lower = password.toLowerCase();
  final core = lower.replaceAll(RegExp(r'^[^a-z]+|[^a-z]+$'), '');
  if (_common.contains(lower) || _common.contains(core)) {
    return PasswordStrength.weak;
  }
  // One character repeated, or a short block repeated ("abcabcabc").
  if (RegExp(r'^(.{1,4})\1+$').hasMatch(lower)) return PasswordStrength.weak;
  // Mostly an alphabet / number / keyboard run ("abcdefgh", "12345678").
  for (final seq in _sequences) {
    final rev = seq.split('').reversed.join();
    for (final s in [seq, rev]) {
      if (_containsRun(lower, s, math.max(6, lower.length - 2))) {
        return PasswordStrength.weak;
      }
    }
  }
  // Digits only: dates, PINs and phone numbers are guessed first.
  if (RegExp(r'^[0-9]+$').hasMatch(password) && chars.length < 16) {
    return PasswordStrength.weak;
  }

  var pool = 0;
  if (RegExp('[a-z]').hasMatch(password)) pool += 26;
  if (RegExp('[A-Z]').hasMatch(password)) pool += 26;
  if (RegExp('[0-9]').hasMatch(password)) pool += 10;
  if (RegExp(r'[^a-zA-Z0-9\s]').hasMatch(password)) pool += 33;
  if (RegExp(r'\s').hasMatch(password)) pool += 1;
  // Fewer distinct characters than length means repeats: count those only.
  final distinct = chars.toSet().length;
  final effective = math.min(chars.length, distinct * 2);
  final bits = effective * (math.log(math.max(pool, 2)) / math.ln2);
  if (bits >= 64 && chars.length >= 12) return PasswordStrength.strong;
  if (bits >= 44) return PasswordStrength.fair;
  return PasswordStrength.weak;
}

bool _containsRun(String text, String seq, int n) {
  for (var i = 0; i + n <= seq.length; i++) {
    if (text.contains(seq.substring(i, i + n))) return true;
  }
  return false;
}
