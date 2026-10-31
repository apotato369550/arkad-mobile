import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'store.dart';

AttachmentStore createStore() => NativeAttachmentStore();

class NativeAttachmentStore implements AttachmentStore {
  NativeAttachmentStore({this.root});
  final Directory? root;
  Future<File> _file(String id) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Invalid attachment ID');
    }
    final root = this.root ?? await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/chat-images');
    await directory.create(recursive: true);
    return File('${directory.path}/$id.jpg');
  }

  @override
  Future<Uint8List?> read(String id) async {
    final file = await _file(id);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    await (await _file(id)).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
  }
}
