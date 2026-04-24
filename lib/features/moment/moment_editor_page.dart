import '../../core/widgets/cdn_image.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../core/services/moment_service.dart';
import '../../models/moment.dart';

class MomentsEditorPage extends StatefulWidget {
  final Moment? editMoment;
  const MomentsEditorPage({super.key, this.editMoment});

  @override
  State<MomentsEditorPage> createState() => _MomentsEditorPageState();
}

class _MomentsEditorPageState extends State<MomentsEditorPage> {
  final TextEditingController _contentController = TextEditingController();
  final MomentsService _service = MomentsService();

  bool _isSubmitting = false;
  File? _selectedImage;
  String _mood = '😊';
  bool _showEmojiPicker = false;
  bool _removeExistingImage = false;

  late DateTime _postDate;
  late TimeOfDay _postTime;

  @override
  void initState() {
    super.initState();
    final initialDate = widget.editMoment?.date ?? DateTime.now();
    _postDate = initialDate;
    _postTime = TimeOfDay.fromDateTime(initialDate);

    if (widget.editMoment != null) {
      _contentController.text = widget.editMoment!.content;
      _mood = widget.editMoment!.mood ?? '😊';
      // Loading existing image is trickier as it's a URL, not File.
      // We'll handle UI to show network image if _selectedImage is null but widget.editMoment.image is not.
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _postDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _postDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _postTime,
    );
    if (picked != null) {
      setState(() => _postTime = picked);
    }
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        _selectedImage = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submit() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先写点什么')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final DateTime finalDateTime = DateTime(
        _postDate.year,
        _postDate.month,
        _postDate.day,
        _postTime.hour,
        _postTime.minute,
        0, // seconds
      );

      final moment = Moment(
        date: finalDateTime,
        content: _contentController.text,
        mood: _mood,
        // If remove flag is set, force empty. Else if new image selected, null (auto-filled by upload). Else keep old.
        image: _removeExistingImage
            ? ''
            : (_selectedImage == null ? widget.editMoment?.image : null),
      );

      if (widget.editMoment != null) {
        await _service.updateMoment(
          widget.editMoment!,
          moment,
          newImage: _selectedImage,
        );
      } else {
        await _service.addMoment(moment, imageFile: _selectedImage);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('发布失败，请重试')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Moment'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Display
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateFormat('yyyy-MM-dd').format(_postDate)),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(_postTime.format(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Content Input
                TextField(
                  controller: _contentController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: "What's on your mind?",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Mood Selector
                const Text(
                  'Mood',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(_mood, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showEmojiPicker = !_showEmojiPicker;
                          FocusScope.of(context).unfocus(); // Hide keyboard
                        });
                      },
                      icon: const Icon(Icons.emoji_emotions),
                      label: const Text('Choose Emoji'),
                    ),
                  ],
                ),
                if (_showEmojiPicker)
                  SizedBox(
                    height: 300,
                    child: EmojiPicker(
                      onEmojiSelected: (category, emoji) {
                        setState(() {
                          _mood = emoji.emoji;
                          _showEmojiPicker = false;
                        });
                      },
                      config: Config(
                        height: 300,
                        checkPlatformCompatibility: true,
                        viewOrderConfig: const ViewOrderConfig(),
                        emojiViewConfig: EmojiViewConfig(
                          emojiSizeMax: 28,
                          columns: 9, // Keeping 9 for desktop constraint
                        ),
                        skinToneConfig: const SkinToneConfig(),
                        categoryViewConfig: const CategoryViewConfig(),
                        bottomActionBarConfig: const BottomActionBarConfig(),
                        searchViewConfig: const SearchViewConfig(),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Image Picker
                const Text(
                  'Photo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickImage,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 200,
                      maxHeight: 600,
                    ),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _buildImagePreview(),
                    ),
                  ),
                ),
                if (_selectedImage != null ||
                    (widget.editMoment?.image != null &&
                        widget.editMoment!.image!.isNotEmpty &&
                        !_removeExistingImage))
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_selectedImage != null) {
                          _selectedImage = null;
                        } else {
                          _removeExistingImage = true;
                        }
                      });
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text(
                      'Remove Photo',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                // Show "Undo Remove" if we marked existing image for removal
                if (_removeExistingImage)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _removeExistingImage = false),
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo Remove Photo'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(_selectedImage!, fit: BoxFit.contain),
      );
    } else if (_removeExistingImage) {
      return const SizedBox(
        height: 200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('Image removed', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    } else if (widget.editMoment?.image != null &&
        widget.editMoment!.image!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: NetImage(
          imageUrl: widget.editMoment!.image!,
          fit: BoxFit.contain,
          errorWidget: (context, url, error) => const SizedBox(
            height: 200,
            child: Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
            ),
          ),
        ),
      );
    } else {
      return const SizedBox(
        height: 200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('Add a photo', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
  }
}
