import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class MessageInput extends StatefulWidget {
  final bool isEnabled;
  final bool isGenerating;
  final Function(String text, {Uint8List? imageBytes, String? imagePath})
      onSend;

  const MessageInput({
    super.key,
    required this.isEnabled,
    required this.isGenerating,
    required this.onSend,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  Uint8List? _pendingImageBytes;
  String? _pendingImagePath;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/chat_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = pickedFile.path.split('.').last.toLowerCase();
      final savedPath = '${imagesDir.path}/img_$timestamp.$fileExtension';
      final savedFile = File(savedPath);
      await savedFile.writeAsBytes(bytes);

      setState(() {
        _pendingImageBytes = bytes;
        _pendingImagePath = savedPath;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _clearImage() {
    setState(() {
      _pendingImageBytes = null;
      _pendingImagePath = null;
    });
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if ((text.isEmpty && _pendingImageBytes == null) ||
        !widget.isEnabled ||
        widget.isGenerating) {
      return;
    }
    widget.onSend(
      text.isEmpty ? 'Describe this image.' : text,
      imageBytes: _pendingImageBytes,
      imagePath: _pendingImagePath,
    );
    _controller.clear();
    _clearImage();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingImageBytes != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: Image.memory(
                        _pendingImageBytes!,
                        fit: BoxFit.cover,
                        width: 120,
                        height: 120,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _clearImage,
                    icon: Icon(Icons.close, color: colorScheme.error, size: 20),
                    tooltip: 'Remove image',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              if (widget.isEnabled && !widget.isGenerating)
                IconButton(
                  onPressed: _pickImage,
                  icon: Icon(Icons.image_outlined, color: colorScheme.primary),
                  tooltip: 'Attach image',
                )
              else
                const SizedBox(width: 48),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.isEnabled,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: colorScheme.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    filled: !widget.isEnabled,
                    fillColor: widget.isEnabled
                        ? null
                        : colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              widget.isGenerating
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colorScheme.primary,
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: widget.isEnabled ? _handleSend : null,
                      icon:
                          Icon(Icons.send_rounded, color: colorScheme.primary),
                      tooltip: 'Send',
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
