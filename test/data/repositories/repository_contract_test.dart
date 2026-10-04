import 'package:flutter_test/flutter_test.dart';
import 'package:kasaran/data/repositories/repository.dart';

class FakeRepository implements Repository<String, int> {
  final values = <int, String>{};

  @override
  Future<String?> find(int id) async => values[id];

  @override
  Future<void> save(int id, String value) async => values[id] = value;

  @override
  Future<void> remove(int id) async => values.remove(id);
}

void main() {
  test('repository contract can be implemented without a backend', () async {
    final repository = FakeRepository();
    expect(await repository.find(42), isNull);
    await repository.save(42, 'synthetic');
    expect(await repository.find(42), 'synthetic');
    await repository.remove(42);
    expect(await repository.find(42), isNull);
  });
}
