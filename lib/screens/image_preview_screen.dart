import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../services/chat_service.dart';
import '../models/index.dart';

class ImagePreviewScreen extends StatefulWidget {
  final String imageUrl;
  final Message message;
  final String chatId;
  final bool isMe;

  const ImagePreviewScreen({
    super.key,
    required this.imageUrl,
    required this.message,
    required this.chatId,
    required this.isMe,
  });

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  final ChatService _chatService = ChatService();
  bool _isSaving = false;

  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    try {
      final bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      final tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await Dio().download(widget.imageUrl, path);
      await Gal.putImage(path);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الصورة في الاستوديو')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteImage() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('حذف الصورة', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل أنت متأكد من حذف هذه الصورة؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (widget.isMe) {
          await _chatService.deleteMessageForEveryone(
            chatId: widget.chatId,
            messageId: widget.message.id,
          );
        } else {
          await _chatService.deleteMessageForMe(
            chatId: widget.chatId,
            messageId: widget.message.id,
            userId: widget.message.receiverId,
          );
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الصورة')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الحذف: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLocal = !widget.imageUrl.startsWith('http');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!isLocal)
            IconButton(
              icon: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded, color: Colors.white),
              onPressed: _isSaving ? null : _saveImage,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _deleteImage,
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: isLocal
              ? Image.file(
                  File(widget.imageUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white38, size: 50),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image,
                    color: Colors.white38,
                    size: 50,
                  ),
                ),
        ),
      ),
    );
  }
}
