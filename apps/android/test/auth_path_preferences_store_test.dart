import 'package:flutter_test/flutter_test.dart';
import 'package:soup/src/data/session/auth_path_preferences_store.dart';

void main() {
  test('MemoryAuthPathStore round trips direct opt-in', () async {
    final store = MemoryAuthPathStore();
    expect(await store.read(), isNull);

    await store.write(AuthPath.direct);
    expect(await store.read(), AuthPath.direct);

    await store.write(AuthPath.soup);
    expect(await store.read(), AuthPath.soup);
  });
}
