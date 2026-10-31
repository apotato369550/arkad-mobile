import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/attachments/store.dart';

class ChatImage extends StatefulWidget {
  const ChatImage({super.key, required this.id, required this.store});
  final String id;
  final AttachmentStore store;
  @override
  State<ChatImage> createState() => _ChatImageState();
}

class _ChatImageState extends State<ChatImage> {
  late Future<Uint8List?> _bytes;
  @override
  void initState() {
    super.initState();
    _bytes = widget.store.read(widget.id);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _bytes,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes == null) {
        return Text(
          snapshot.connectionState == ConnectionState.waiting
              ? 'Loading image…'
              : 'Image unavailable',
        );
      }
      return Semantics(
        label: 'Attached image. Tap to expand.',
        button: true,
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              child: Stack(
                children: [
                  InteractiveViewer(child: Image.memory(bytes)),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      tooltip: 'Close image',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Image.memory(
              bytes,
              width: 220,
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    },
  );
}
