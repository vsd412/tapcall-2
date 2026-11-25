import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class Person {
  const Person(this.name, this.number, [this.photo]);

  final Uint8List? photo;

  final String name;
  final String number;

  static String? parseNumber(String input) {
    final compact = input.trim().replaceAll(RegExp(r'[\s().-]'), '');
    if (RegExp(r'^\d{8}$').hasMatch(compact)) return '852$compact';
    final digits = compact.startsWith('+')
        ? compact.substring(1)
        : compact.startsWith('00')
        ? compact.substring(2)
        : '';
    return RegExp(r'^[1-9]\d{5,14}$').hasMatch(digits) ? digits : null;
  }
}

class ContactBook {
  static const _key = 'people.v1';

  Future<List<Person>> read() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).map((row) {
      final data = jsonDecode(row) as Map<String, dynamic>;
      final image = data['photo'] as String?;
      return Person(
        data['name'] as String,
        data['number'] as String,
        image == null ? null : base64Decode(image),
      );
    }).toList();
  }

  Future<void> write(List<Person> people) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setStringList(_key, [
      for (final p in people)
        jsonEncode({
          'name': p.name,
          'number': p.number,
          if (p.photo != null) 'photo': base64Encode(p.photo!),
        }),
    ]);
    if (!saved) throw StateError('Contact write failed');
  }
}
