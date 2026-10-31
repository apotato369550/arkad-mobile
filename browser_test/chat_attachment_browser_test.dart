import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:arkad_mobile/services/attachments/store_web.dart';

void main() {
  test(
    'IndexedDB retains images across store instances and deletes them',
    () async {
      final id = 'test_${DateTime.now().microsecondsSinceEpoch}';
      final first = BrowserAttachmentStore();
      final bytes = Uint8List.fromList([255, 216, 255, 217]);
      try {
        await first.write(id, bytes);
        final reopened = BrowserAttachmentStore();
        expect(await reopened.read(id), bytes);
        await reopened.delete(id);
        expect(await first.read(id), isNull);
      } finally {
        await first.delete(id);
      }
    },
  );
}
