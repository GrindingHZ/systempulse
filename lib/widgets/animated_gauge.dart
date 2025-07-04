import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedGauge extends StatefulWidget {
  final double value;
  final String label;
  final Color color;
  final double size;
  final double strokeWidth;
  final bool showAnimation;

  const AnimatedGauge({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.size = 120,
    this.strokeWidth = 8,
    this.showAnimation = true,
  });

  @override
  State<AnimatedGauge> createState() => _AnimatedGaugeState();
}

class _AnimatedGaugeState extends State<AnimatedGauge>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _animation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Main value animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Pulse animation for visual appeal
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    if (widget.showAnimation) {
      _animationController.forward();
      _pulseController.repeat(reverse: true);
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_animation, _pulseAnimation, _scaleAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value * _pulseAnimation.value,
            child: CustomPaint(
              painter: EnhancedGaugePainter(
                value: _animation.value,
                color: widget.color,
                strokeWidth: widget.strokeWidth,
                glowIntensity: _pulseAnimation.value - 0.95,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                        fontSize: widget.size * 0.15,
                      ) ?? const TextStyle(),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 800),
                        tween: Tween(end: _animation.value),
                        builder: (context, value, child) {
                          return Text('${value.toStringAsFixed(1)}%');
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: widget.size * 0.08,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class EnhancedGaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final double strokeWidth;
  final double glowIntensity;

  EnhancedGaugePainter({
    required this.value,
    required this.color,
    required this.strokeWidth,
    this.glowIntensity = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth * 2) / 2;

    // Draw outer glow effect
    if (glowIntensity > 0) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: glowIntensity * 0.3)
        ..strokeWidth = strokeWidth + 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(center, radius + 2, glowPaint);
    }

    // Background circle with gradient
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.05),
          color.withValues(alpha: 0.15),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc with gradient
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          color,
          color.withValues(alpha: 0.7),
          color,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2; // Start from top
    final sweepAngle = (value / 100) * 2 * math.pi;

    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );

      // Draw end cap highlight
      final endAngle = startAngle + sweepAngle;
      final endPoint = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );

      final capPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(endPoint, strokeWidth / 3, capPaint);
    }

    // Inner shadow/depth effect
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius - strokeWidth / 2, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is EnhancedGaugePainter &&
        (oldDelegate.value != value ||
            oldDelegate.color != color ||
            oldDelegate.strokeWidth != strokeWidth ||
            oldDelegate.glowIntensity != glowIntensity);
  }
}
