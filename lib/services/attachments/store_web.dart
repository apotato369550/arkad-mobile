import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'store.dart';

AttachmentStore createStore() => BrowserAttachmentStore();

class BrowserAttachmentStore implements AttachmentStore {
  Future<web.IDBDatabase>? _database;
  Future<web.IDBDatabase> _open() => _database ??= () async {
    final request = web.window.indexedDB.open('arkad-chat-images', 1);
    final result = Completer<web.IDBDatabase>();
    request.addEventListener(
      'upgradeneeded',
      ((web.Event _) {
        (request.result as web.IDBDatabase).createObjectStore('images');
      }).toJS,
    );
    request.addEventListener(
      'success',
      ((web.Event _) {
        result.complete(request.result as web.IDBDatabase);
      }).toJS,
    );
    request.addEventListener(
      'error',
      ((web.Event _) {
        result.completeError(
          StateError('Browser image storage is unavailable.'),
        );
      }).toJS,
    );
    return result.future;
  }();
  Future<JSAny?> _run(String id, String operation, [Uint8List? bytes]) async {
    final db = await _open();
    final tx = db.transaction(
      'images'.toJS,
      operation == 'read' ? 'readonly' : 'readwrite',
    );
    final store = tx.objectStore('images');
    final request = switch (operation) {
      'read' => store.get(id.toJS),
      'write' => store.put(base64Encode(bytes!).toJS, id.toJS),
      _ => store.delete(id.toJS),
    };
    final result = Completer<JSAny?>();
    JSAny? value;
    request.addEventListener(
      'success',
      ((web.Event _) {
        value = request.result;
      }).toJS,
    );
    tx.addEventListener(
      'complete',
      ((web.Event _) {
        if (!result.isCompleted) result.complete(value);
      }).toJS,
    );
    void fail(web.Event _) {
      if (!result.isCompleted) {
        result.completeError(
          StateError('Browser storage failed or its quota was exceeded.'),
        );
      }
    }

    tx.addEventListener('abort', fail.toJS);
    tx.addEventListener('error', fail.toJS);
    return result.future;
  }

  @override
  Future<Uint8List?> read(String id) async {
    final value = await _run(id, 'read');
    return value == null || value.isUndefinedOrNull
        ? null
        : base64Decode((value as JSString).toDart);
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    await _run(id, 'write', bytes);
  }

  @override
  Future<void> delete(String id) async {
    await _run(id, 'delete');
  }
}
