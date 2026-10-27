import 'package:flutter/material.dart';
import '../models/message_model.dart';

class MessageOptionsSheet extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback onDeleteForMe;
  final VoidCallback? onDeleteForEveryone;
  final VoidCallback? onEdit;

  const MessageOptionsSheet({
    super.key,
    required this.message,
    required this.isMe,
    required this.onDeleteForMe,
    this.onDeleteForEveryone,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // مؤشر السحب
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // خيار التعديل (للمرسل والرسائل النصية فقط)
          if (onEdit != null)
            _buildOption(
              icon: Icons.edit,
              label: 'تعديل',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                onEdit!();
              },
            ),

          // خيار حذف لدي
          _buildOption(
            icon: Icons.delete_outline,
            label: 'حذف لدي',
            color: Colors.orange,
            onTap: () {
              Navigator.pop(context);
              onDeleteForMe();
            },
          ),

          // خيار حذف للجميع (للمرسل فقط)
          if (onDeleteForEveryone != null)
            _buildOption(
              icon: Icons.delete_forever,
              label: 'حذف للجميع',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteForEveryoneConfirmation(context);
              },
            ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteForEveryoneConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف للجميع؟'),
        content: const Text(
          'سيتم حذف هذه الرسالة للجميع. لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onDeleteForEveryone!();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
