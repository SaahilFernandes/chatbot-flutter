import 'package:flutter/material.dart';



// --- Animated Typing Dots Widget (can be in the same file or a new .dart file) ---
class AnimatedTypingDots extends StatefulWidget {
  const AnimatedTypingDots({super.key, this.color, this.dotSize = 8.0});
  final Color? color;
  final double dotSize;

  @override
  State<AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<AnimatedTypingDots>
    with TickerProviderStateMixin {
  late AnimationController _dot1Controller;
  late AnimationController _dot2Controller;
  late AnimationController _dot3Controller;

  late Animation<double> _dot1Animation;
  late Animation<double> _dot2Animation;
  late Animation<double> _dot3Animation;

  final Duration _duration = const Duration(milliseconds: 600); // Speed of one pulse
  final Duration _delayMultiple = const Duration(milliseconds: 200); // Delay between dots

  @override
  void initState() {
    super.initState();
    _dot1Controller = AnimationController(vsync: this, duration: _duration);
    _dot2Controller = AnimationController(vsync: this, duration: _duration);
    _dot3Controller = AnimationController(vsync: this, duration: _duration);

    _dot1Animation = _createAnimation(_dot1Controller);
    _dot2Animation = _createAnimation(_dot2Controller);
    _dot3Animation = _createAnimation(_dot3Controller);

    // Start animations with delays
    _dot1Controller.repeat(reverse: true);
    Future.delayed(_delayMultiple, () {
      if (mounted) _dot2Controller.repeat(reverse: true);
    });
    Future.delayed(_delayMultiple * 2, () {
      if (mounted) _dot3Controller.repeat(reverse: true);
    });
  }

  Animation<double> _createAnimation(AnimationController controller) {
    return Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _dot1Controller.dispose();
    _dot2Controller.dispose();
    _dot3Controller.dispose();
    super.dispose();
  }

  Widget _buildDot(Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: Container(
        width: widget.dotSize,
        height: widget.dotSize,
        margin: const EdgeInsets.symmetric(horizontal: 2.5),
        decoration: BoxDecoration(
          color: widget.color ?? Colors.grey[700],
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(_dot1Animation),
        _buildDot(_dot2Animation),
        _buildDot(_dot3Animation),
      ],
    );
  }
}
// --- End Animated Typing Dots Widget ---