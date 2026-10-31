import 'package:arah/core/utils/uuid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uuidV4: format RFC 4122 versi 4 (yang divalidasi z.string().uuid() di backend), tidak berulang', () {
    final pattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final ids = List.generate(500, (_) => uuidV4());
    expect(ids.every(pattern.hasMatch), isTrue);
    expect(ids.toSet().length, ids.length);
  });
}
