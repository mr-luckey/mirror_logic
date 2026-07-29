import 'dart:convert';

import 'package:hive/hive.dart';

class LocalStorageService {
  LocalStorageService(this._box);

  final Box<dynamic> _box;

  Future<void> writeString(String key, String value) async {
    await _box.put(key, value);
  }

  String? readString(String key) => _box.get(key) as String?;

  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    await _box.put(key, jsonEncode(value));
  }

  Map<String, dynamic>? readJson(String key) {
    final raw = _box.get(key);
    if (raw is! String || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  Future<void> writeBool(String key, bool value) async {
    await _box.put(key, value);
  }

  bool readBool(String key, {bool defaultValue = false}) {
    return _box.get(key, defaultValue: defaultValue) as bool? ?? defaultValue;
  }

  Future<void> writeInt(String key, int value) async {
    await _box.put(key, value);
  }

  int readInt(String key, {int defaultValue = 0}) {
    return _box.get(key, defaultValue: defaultValue) as int? ?? defaultValue;
  }

  Future<void> writeDouble(String key, double value) async {
    await _box.put(key, value);
  }

  double readDouble(String key, {double defaultValue = 0}) {
    return (_box.get(key, defaultValue: defaultValue) as num?)?.toDouble() ??
        defaultValue;
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
  }
}
