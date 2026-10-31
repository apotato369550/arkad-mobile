import 'dart:typed_data';
import 'store_stub.dart'
    if (dart.library.io) 'store_native.dart'
    if (dart.library.js_interop) 'store_web.dart'
    as platform;

abstract class AttachmentStore {
  Future<Uint8List?> read(String id);
  Future<void> write(String id, Uint8List bytes);
  Future<void> delete(String id);
}

AttachmentStore createAttachmentStore() => platform.createStore();
