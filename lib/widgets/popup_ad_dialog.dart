import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class PopupAdDialog extends StatefulWidget {
  final Map<String, dynamic> adData;

  const PopupAdDialog({Key? key, required this.adData}) : super(key: key);

  @override
  State<PopupAdDialog> createState() => _PopupAdDialogState();
}

class _PopupAdDialogState extends State<PopupAdDialog> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 2.0, end: 15.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _launchUrl() async {
    final linkUrl = widget.adData['linkUrl'] ?? '';
    if (linkUrl.isNotEmpty) {
      final uri = Uri.parse(linkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.adData['title'] ?? 'إعلان جديد';
    final description = widget.adData['description'] ?? '';
    final imageUrl = widget.adData['imageUrl'] ?? '';
    final linkUrl = widget.adData['linkUrl'] ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.transparent,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Golden Title
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                            blurRadius: _glowAnimation.value,
                            spreadRadius: _glowAnimation.value / 4,
                          )
                        ],
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFFD700), // Gold
                          shadows: [
                            Shadow(
                              color: const Color(0xFFFFA500), // Orange glow
                              blurRadius: _glowAnimation.value / 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                // Full Size Image or Fallback Content
                Flexible(
                  child: GestureDetector(
                    onTap: _launchUrl,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: imageUrl.isNotEmpty
                          ? Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                                  ),
                                  child: Image.network(
                                    imageUrl,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Padding(
                                      padding: EdgeInsets.all(32.0),
                                      child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                if (linkUrl.isNotEmpty) // Visual cue to click
                                  Positioned(
                                    bottom: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.touch_app, color: Colors.white, size: 16),
                                          const SizedBox(width: 6),
                                          Text('اضغط للتفاصيل', style: GoogleFonts.cairo(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.campaign_rounded, size: 60, color: Color(0xFF009688)),
                                    const SizedBox(height: 16),
                                    Text(
                                      description,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.tajawal(
                                        fontSize: 16,
                                        color: Colors.black87,
                                        height: 1.5,
                                      ),
                                    ),
                                    if (linkUrl.isNotEmpty) ...[
                                      const SizedBox(height: 24),
                                      ElevatedButton(
                                        onPressed: _launchUrl,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF009688),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        child: Text(widget.adData['buttonText'] ?? 'التفاصيل', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Close button wrapper (top left or right depending on RTL)
          Positioned(
            top: -15,
            right: -15,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
