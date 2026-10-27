import 'package:flutter/material.dart';

/// A premium sound level / volume meter for player voice indicator
class VoiceVolumeMeter extends StatelessWidget {
  final int volumeLevel;
  final bool isMuted;
  
  const VoiceVolumeMeter({
    super.key,
    required this.volumeLevel,
    required this.isMuted,
  });

  @override
  Widget build(BuildContext context) {
    // Map volume level (0-255) to active bars count (0-5)
    int activeBars = 0;
    if (!isMuted && volumeLevel > 15) {
      if (volumeLevel < 45) activeBars = 1;
      else if (volumeLevel < 90) activeBars = 2;
      else if (volumeLevel < 135) activeBars = 3;
      else if (volumeLevel < 180) activeBars = 4;
      else activeBars = 5;
    }

    // Colors for each bar when active
    final List<Color> activeColors = [
      const Color(0xFF00E676), // Bar 1 (bottom): Green
      const Color(0xFF00E676), // Bar 2: Green
      const Color(0xFFAEEA00), // Bar 3: Lime
      const Color(0xFFFFD600), // Bar 4: Yellow/Orange
      const Color(0xFFFF1744), // Bar 5 (top): Red
    ];

    return Container(
      height: 20, // Stable layout height
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          // Top bar is index 0 (maps to Bar 5), bottom bar is index 4 (maps to Bar 1)
          final barPosition = 5 - index;
          final bool isActive = activeBars >= barPosition;

          Color barColor;
          if (isMuted) {
            barColor = Colors.black12;
          } else if (isActive) {
            barColor = activeColors[barPosition - 1];
          } else {
            barColor = Colors.black45; // Dark/grey when silent
          }

          return Container(
            width: 12,
            height: 2.2,
            margin: const EdgeInsets.only(bottom: 1.2),
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(1.5),
              boxShadow: isActive && !isMuted
                  ? [
                      BoxShadow(
                        color: barColor.withValues(alpha: 0.3),
                        blurRadius: 1,
                        spreadRadius: 0.2,
                      )
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}
