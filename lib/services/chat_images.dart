import 'package:image/image.dart' as image;
import 'package:flutter/foundation.dart';

const maxChatImageBytes = 1024 * 1024;
const maxChatStorageBytes = 20 * maxChatImageBytes;
Future<Uint8List> prepareChatImage(Uint8List source) =>
    compute(_prepare, source);
Uint8List _prepare(Uint8List source) {
  if (source.length > 10 * maxChatImageBytes) {
    throw const FormatException('Source images must be 10 MiB or smaller.');
  }
  final decoder = image.findDecoderForData(source);
  if (decoder is! image.JpegDecoder &&
      decoder is! image.PngDecoder &&
      decoder is! image.WebPDecoder) {
    throw const FormatException('Choose a JPEG, PNG or WebP image.');
  }
  final info = decoder!.startDecode(source);
  if (info == null || info.width * info.height > 20000000) {
    throw const FormatException('Image is corrupt or exceeds 20 megapixels.');
  }
  final decoded = decoder.decodeFrame(0);
  if (decoded == null) throw const FormatException('Cannot decode image.');
  var resized = image.bakeOrientation(decoded);
  if (resized.width > 1600 || resized.height > 1600) {
    resized = resized.width >= resized.height
        ? image.copyResize(resized, width: 1600)
        : image.copyResize(resized, height: 1600);
  }
  final clean = image.Image(
    width: resized.width,
    height: resized.height,
    numChannels: 3,
  );
  image.fill(clean, color: image.ColorRgb8(255, 255, 255));
  image.compositeImage(clean, resized);
  for (final quality in [85, 70, 55, 40]) {
    final bytes = image.encodeJpg(clean, quality: quality);
    if (bytes.length <= maxChatImageBytes) return bytes;
  }
  throw const FormatException('Could not fit this image within 1 MiB.');
}
