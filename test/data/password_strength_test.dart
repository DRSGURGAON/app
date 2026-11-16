import 'package:docsafe/data/services/password_strength.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('too short below the minimum length', () {
    expect(passwordStrength(''), PasswordStrength.tooShort);
    expect(passwordStrength('Ab1!x9'), PasswordStrength.tooShort);
  });

  test('common, repeated, run and digit-only passwords are weak', () {
    for (final p in [
      'password',
      'Password@123',
      'PASSWORD1',
      'qwertyuiop',
      'iloveyou!',
      'Jaishriram@1',
      'aaaaaaaaaa',
      'abcabcabcabc',
      '12345678',
      '87654321',
      'abcdefghij',
      'asdfghjkl1',
      '15081947', // a date
      '9876543210', // a phone number
      'docsafe2026',
    ]) {
      expect(passwordStrength(p), PasswordStrength.weak, reason: p);
    }
  });

  test('fair and strong', () {
    expect(passwordStrength('Mango#Tree7'), PasswordStrength.fair);
    expect(passwordStrength('blue river'), PasswordStrength.fair);
    expect(
      passwordStrength('Neela Aasmaan, 3 chidiya!'),
      PasswordStrength.strong,
    );
    expect(passwordStrength('t7#Kq!m2Zp9@Lr'), PasswordStrength.strong);
    expect(
      passwordStrength('correct horse battery staple'),
      PasswordStrength.strong,
    );
  });

  test('longer is never weaker for the same style', () {
    final order = PasswordStrength.values;
    var prev = PasswordStrength.tooShort;
    for (final p in ['Rx7#qL', 'Rx7#qL2m', 'Rx7#qL2mW9', 'Rx7#qL2mW9!vB4']) {
      final s = passwordStrength(p);
      expect(
        order.indexOf(s),
        greaterThanOrEqualTo(order.indexOf(prev)),
        reason: p,
      );
      prev = s;
    }
    expect(prev, PasswordStrength.strong);
  });
}
