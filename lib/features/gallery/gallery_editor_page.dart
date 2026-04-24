import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/widgets/cdn_image.dart';
import '../../models/gallery_item.dart';
import '../../core/services/gallery_service.dart';

class GalleryEditorPage extends StatefulWidget {
  final GalleryItem? editItem;

  const GalleryEditorPage({super.key, this.editItem});

  @override
  State<GalleryEditorPage> createState() => _GalleryEditorPageState();
}

class _GalleryEditorPageState extends State<GalleryEditorPage> {
  final TextEditingController _captionController = TextEditingController();
  final GalleryService _service = GalleryService();

  bool _isSubmitting = false;
  File? _selectedImage;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.editItem != null) {
      _captionController.text = widget.editItem!.caption;
      _existingImageUrl = widget.editItem!.url;
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
    if (_selectedImage == null && _existingImageUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an image!')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final item = GalleryItem(
        url:
            _existingImageUrl ??
            '', // Will be updated by service if file provided
        caption: _captionController.text,
      );

      if (widget.editItem != null) {
        await _service.updateGalleryItem(
          widget.editItem!,
          item,
          newImageFile: _selectedImage,
        );
      } else {
        // Create stub item, service will fill URL
        await _service.addGalleryItem(item, imageFile: _selectedImage);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
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
        title: Text(widget.editItem == null ? 'New Photo' : 'Edit Photo'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Picker
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
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.contain,
                              ), // Adjust fit
                            )
                          : (_existingImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: NetImage(
                                      imageUrl: _existingImageUrl!,
                                      fit: BoxFit.contain, // Adjust fit
                                      placeholder: (context, url) =>
                                          const SizedBox(
                                            height: 200,
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          ),
                                      errorWidget: (context, url, error) =>
                                          const SizedBox(
                                            height: 200,
                                            child: Center(
                                              child: Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                                size: 48,
                                              ),
                                            ),
                                          ),
                                    ),
                                  )
                                : const SizedBox(
                                    height: 200, // Default height
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Tap to select photo',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Caption Input
                TextField(
                  controller: _captionController,
                  maxLines: 3,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontFamily: 'Source Han Serif CN', // Consistent font
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Caption',
                    hintText: 'Add a description...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
