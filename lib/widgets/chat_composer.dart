import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_images.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSend,
    this.autofocus = false,
    this.focusNode,
  });
  final TextEditingController controller;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final Future<void> Function(List<Uint8List>) onSend;
  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _images = <Uint8List>[];
  bool _busy = false;
  bool _focused = false;
  String? _error;
  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final files = await ImagePicker().pickMultiImage(limit: 3);
      if (files.length + _images.length > 3) {
        throw const FormatException('Attach up to 3 images per message.');
      }
      final prepared = <Uint8List>[];
      for (final file in files) {
        if (await file.length() > 10 * maxChatImageBytes) {
          throw const FormatException('Source image exceeds 10 MiB.');
        }
        prepared.add(await prepareChatImage(await file.readAsBytes()));
      }
      if (mounted) setState(() => _images.addAll(prepared));
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not attach image: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_busy ||
        !widget.enabled ||
        (widget.controller.text.trim().isEmpty && _images.isEmpty)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSend(List.of(_images));
      if (mounted) setState(_images.clear);
    } catch (e) {
      if (mounted) setState(() => _error = 'Message not sent: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_images.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _images.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.iconTile),
                      child: Image.memory(
                        _images[i],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        tooltip: 'Remove image ${i + 1}',
                        onPressed: _busy
                            ? null
                            : () => setState(() => _images.removeAt(i)),
                        icon: const Icon(Icons.cancel),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _error!,
            style: AppTextStyles.metadata(color: AppColors.clay),
          ),
        ),
      Focus(
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter &&
              widget.controller.value.composing.isCollapsed) {
            if (!HardwareKeyboard.instance.isShiftPressed) _send();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          key: const ValueKey('chat-input-bar'),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(AppRadii.input),
            border: Border.all(
              color: _focused
                  ? AppColors.darkGreen
                  : AppColors.ink.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Attach images (up to 3)',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: widget.enabled && !_busy ? _pick : null,
                icon: const Icon(Icons.attach_file),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  autofocus: widget.autofocus,
                  enabled: widget.enabled && !_busy,
                  minLines: 1,
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  inputFormatters: [_SingleLineChatFormatter()],
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: widget.enabled
                        ? 'Message Arkad…'
                        : 'Add an API key to chat',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              IconButton.filled(
                tooltip: 'Send message',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.darkGreen,
                  foregroundColor: AppColors.paper,
                ),
                onPressed: widget.enabled && !_busy ? _send : null,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward),
              ),
            ],
          ),
        ),
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              'Images are shared with your AI provider.',
              style: AppTextStyles.metadata(),
            ),
          ),
          IconButton(
            tooltip: 'Image limits and privacy',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.info_outline, size: 18),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Images and privacy'),
                content: const Text(
                  'Up to 3 images per message. Inputs: 10 MiB / 20 megapixels each. Images are resized to 1600 pixels and 1 MiB each, with 20 MiB retained total. Images are sent to OpenRouter and retained in chat and optional backups.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

class _SingleLineChatFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    return newValue.copyWith(
      text: newValue.text.replaceAll(RegExp(r'[\r\n]'), ' '),
    );
  }
}
