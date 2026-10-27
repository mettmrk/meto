import 'package:flutter/material.dart';

/// A shiny gold coin widget drawn entirely in code.
/// [size] controls the diameter of the coin.
class GoldCoin extends StatelessWidget {
  final double size;

  const GoldCoin({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    // Bottom padding compensates for Flutter's hidden text line-metric padding,
    // ensuring the coin aligns visually with adjacent number text in a Row.
    return Padding(
      padding: EdgeInsets.only(bottom: size * 0.1),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.35, -0.35),
            radius: 0.85,
            colors: [
              Color(0xFFFFF176), // bright highlight
              Color(0xFFFFD700), // pure gold
              Color(0xFFDAA520), // mid gold
              Color(0xFFB8860B), // dark gold edge
            ],
            stops: [0.0, 0.35, 0.70, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withOpacity(0.55),
              blurRadius: size * 0.35,
              spreadRadius: size * 0.05,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: size * 0.2,
              offset: Offset(size * 0.08, size * 0.1),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Inner ring
            Container(
              width: size * 0.72,
              height: size * 0.72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFEE77).withOpacity(0.55),
                  width: size * 0.04,
                ),
              ),
            ),
            // Specular shine spot (top-left glare)
            Positioned(
              top: size * 0.1,
              left: size * 0.14,
              child: Container(
                width: size * 0.22,
                height: size * 0.14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size),
                  color: Colors.white.withOpacity(0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
