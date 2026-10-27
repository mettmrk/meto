import 'package:animated_emoji/animated_emoji.dart';
import 'package:flutter/material.dart';
import '../services/ludo_service.dart';

class LudoInteractionBottomSheet extends StatefulWidget {
  final String? roomId;
  final String
  interactionType; // Not strictly used in new layout but kept for compatibility
  final void Function(String type, String content)? onSend;
  final VoidCallback? onClose;
  final double? height;

  const LudoInteractionBottomSheet({
    super.key,
    this.roomId,
    required this.interactionType,
    this.onSend,
    this.onClose,
    this.height,
  });

  @override
  State<LudoInteractionBottomSheet> createState() =>
      _LudoInteractionBottomSheetState();
}

class _LudoInteractionBottomSheetState
    extends State<LudoInteractionBottomSheet> {
  final TextEditingController _chatController = TextEditingController();
  bool _showManualChat = false;

  static final List<String> _quickPhrases = [
    'أوبس',
    'هههههههههه',
    'أهلا',
    'العب بسرعة',
    'حركة جيدة',
    'حظ أوفر',
    'مرحبا',
    'سأكلك',
    'كفوووو',
    'شكرا',
    'آسف يا صديقي!',
    'لعبة حلوة',
  ];

  // Flat list of stickers for unified view
  static final List<Map<String, dynamic>> _allStickers = [
    {'id': 'haha', 'emoji': AnimatedEmojis.joy},
    {'id': 'love', 'emoji': AnimatedEmojis.heartEyes},
    {'id': 'sad', 'emoji': AnimatedEmojis.cry},
    {'id': 'angry', 'emoji': AnimatedEmojis.angry},
    {'id': 'like', 'emoji': AnimatedEmojis.thumbsUp},
    {'id': 'dislike', 'emoji': AnimatedEmojis.thumbsDown},
    {'id': 'fire', 'emoji': AnimatedEmojis.fire},
    {'id': 'clap', 'emoji': AnimatedEmojis.clap},
    {'id': 'rose', 'emoji': AnimatedEmojis.rose},
    {'id': 'party', 'emoji': AnimatedEmojis.partyingFace},
    {'id': 'rocket', 'emoji': AnimatedEmojis.rocket},
    {'id': 'bomb', 'emoji': AnimatedEmojis.bomb},
    {'id': 'money', 'emoji': AnimatedEmojis.moneyWithWings},
  ];

  void _sendInteraction(String type, String content) {
    if (widget.onSend != null) {
      widget.onSend!(type, content);
    } else if (widget.roomId != null) {
      LudoService().sendInteraction(widget.roomId!, type, content);
    }
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPopup = widget.onClose != null;
    return Container(
      height: widget.height ?? MediaQuery.of(context).size.height * 0.52,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E).withOpacity(0.95),
        borderRadius: isPopup
            ? BorderRadius.circular(24)
            : const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        children: [
          // Scrollable Interaction Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                children: [
                  if (!_showManualChat) ...[
                    // ── Quick Phrases Grid ──
                    GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 3.2,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 9,
                          ),
                      itemCount: _quickPhrases.length,
                      itemBuilder: (context, index) {
                        return _buildPhraseButton(_quickPhrases[index]);
                      },
                    ),

                    const SizedBox(
                      height: 46,
                    ), // Space between comments and stickers
                    // ── Stickers Grid ──
                    GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 9,
                            mainAxisSpacing: 9,
                          ),
                      itemCount: _allStickers.length,
                      itemBuilder: (context, index) {
                        final sticker = _allStickers[index];
                        final emoji = sticker['emoji'] as AnimatedEmojiData;
                        final id = sticker['id'] as String;

                        return GestureDetector(
                          onTap: () => _sendInteraction('sticker', id),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: AnimatedEmoji(emoji, size: 26),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhraseButton(String text) {
    return GestureDetector(
      onTap: () => _sendInteraction('text', text),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
