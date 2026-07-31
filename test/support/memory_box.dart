import 'package:hive/hive.dart';

/// A Hive box that lives in memory.
///
/// The real box holds a file lock that keeps the test runner from exiting on
/// Windows, and no suite needs more than a key-value map. [noSuchMethod] covers
/// the rest of Hive's very wide interface, so anything a test does reach for
/// that is not implemented here fails loudly rather than silently.
class MemoryBox implements Box<dynamic> {
  final _data = <dynamic, dynamic>{};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _data[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => _data[key] = value;

  @override
  Future<void> delete(dynamic key) async => _data.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
