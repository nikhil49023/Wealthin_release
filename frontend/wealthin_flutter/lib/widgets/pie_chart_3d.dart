import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A beautiful 3D-style pie chart with perspective and depth effects
class PieChart3D extends StatefulWidget {
  final Map<String, double> data;
  final List<Color>? colors;
  final double size;
  final double depth;
  final double tilt; // 0.0 to 1.0, perspective tilt amount
  final bool showLabels;
  final bool animate;
  
  const PieChart3D({
    super.key,
    required this.data,
    this.colors,
    this.size = 180,
    this.depth = 20,
    this.tilt = 0.35,
    this.showLabels = true,
    this.animate = true,
  });

  @override
  State<PieChart3D> createState() => _PieChart3DState();
}

class _PieChart3DState extends State<PieChart3D> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  int? _hoveredIndex;
  
  // Premium color palette
  static const List<Color> _defaultColors = [
    Color(0xFFE53935), // Red
    Color(0xFFFB8C00), // Orange  
    Color(0xFF43A047), // Green
    Color(0xFF1E88E5), // Blue
    Color(0xFF8E24AA), // Purple
    Color(0xFF00ACC1), // Cyan
    Color(0xFFFFB300), // Amber
    Color(0xFF5E35B1), // Deep Purple
    Color(0xFF00897B), // Teal
    Color(0xFFD81B60), // Pink
  ];
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  List<Color> get _colors => widget.colors ?? _defaultColors;
  
  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const Center(
          child: Text('No data'),
        ),
      );
    }
    
    final total = widget.data.values.fold(0.0, (sum, v) => sum + v);
    if (total == 0) {
      return SizedBox(width: widget.size, height: widget.size);
    }
    
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size + widget.depth,
          child: CustomPaint(
            painter: _PieChart3DPainter(
              data: widget.data,
              colors: _colors,
              depth: widget.depth,
              tilt: widget.tilt,
              animationValue: _rotationAnimation.value,
              hoveredIndex: _hoveredIndex,
            ),
            child: _buildHitDetection(),
          ),
        );
      },
    );
  }
  
  Widget _buildHitDetection() {
    return GestureDetector(
      onTapDown: (details) {
        final index = _getSegmentAtPosition(details.localPosition);
        if (index != null) {
          setState(() => _hoveredIndex = index);
        }
      },
      onTapUp: (_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _hoveredIndex = null);
        });
      },
      onPanUpdate: (details) {
        final index = _getSegmentAtPosition(details.localPosition);
        if (index != _hoveredIndex) {
          setState(() => _hoveredIndex = index);
        }
      },
      onPanEnd: (_) {
        setState(() => _hoveredIndex = null);
      },
    );
  }
  
  int? _getSegmentAtPosition(Offset position) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final dx = position.dx - center.dx;
    final dy = (position.dy - center.dy) / (1 - widget.tilt * 0.5);
    
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > widget.size / 2 || distance < widget.size / 6) {
      return null;
    }
    
    var angle = math.atan2(dy, dx);
    if (angle < 0) angle += 2 * math.pi;
    
    final total = widget.data.values.fold(0.0, (sum, v) => sum + v);
    var currentAngle = -math.pi / 2;
    
    int index = 0;
    for (final entry in widget.data.entries) {
      final sweepAngle = (entry.value / total) * 2 * math.pi;
      final startAngle = currentAngle + math.pi / 2;
      final endAngle = startAngle + sweepAngle;
      
      if (angle >= startAngle && angle < endAngle) {
        return index;
      }
      currentAngle += sweepAngle;
      index++;
    }
    
    return null;
  }
}

class _PieChart3DPainter extends CustomPainter {
  final Map<String, double> data;
  final List<Color> colors;
  final double depth;
  final double tilt;
  final double animationValue;
  final int? hoveredIndex;
  
  _PieChart3DPainter({
    required this.data,
    required this.colors,
    required this.depth,
    required this.tilt,
    required this.animationValue,
    this.hoveredIndex,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final total = data.values.fold(0.0, (sum, v) => sum + v);
    if (total == 0) return;
    
    final centerX = size.width / 2;
    final centerY = size.height / 2 - depth / 2;
    final radius = (size.width / 2) * 0.9;
    
    // Apply perspective transform (tilt)
    final scaleY = 1 - tilt * 0.5;
    
    // Draw depth layers (3D effect) from back to front
    _drawDepthLayers(canvas, centerX, centerY, radius, scaleY, total);
    
    // Draw the top surface (main pie)
    _drawTopSurface(canvas, centerX, centerY, radius, scaleY, total);
    
    // Draw highlight reflections
    _drawHighlights(canvas, centerX, centerY, radius, scaleY);
  }
  
  void _drawDepthLayers(Canvas canvas, double cx, double cy, double radius, double scaleY, double total) {
    // Draw multiple depth layers for 3D effect
    for (double d = depth * animationValue; d > 0; d -= 2) {
      var startAngle = -math.pi / 2;
      int index = 0;
      
      for (final entry in data.entries) {
        final sweepAngle = (entry.value / total) * 2 * math.pi * animationValue;
        final color = colors[index % colors.length];
        
        // Darker shade for depth
        final depthColor = HSLColor.fromColor(color)
            .withLightness((HSLColor.fromColor(color).lightness * 0.5).clamp(0.0, 1.0))
            .toColor();
        
        final paint = Paint()
          ..color = depthColor
          ..style = PaintingStyle.fill;
        
        final rect = Rect.fromCenter(
          center: Offset(cx, cy + d),
          width: radius * 2,
          height: radius * 2 * scaleY,
        );
        
        canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
        startAngle += sweepAngle;
        index++;
      }
    }
    
    // Draw the depth edges for each segment
    var startAngle = -math.pi / 2;
    int index = 0;
    
    for (final entry in data.entries) {
      final sweepAngle = (entry.value / total) * 2 * math.pi * animationValue;
      final color = colors[index % colors.length];
      
      // Edge color
      final edgeColor = HSLColor.fromColor(color)
          .withLightness((HSLColor.fromColor(color).lightness * 0.6).clamp(0.0, 1.0))
          .toColor();
      
      // Draw the curved edge
      _drawSegmentEdge(canvas, cx, cy, radius, scaleY, startAngle, sweepAngle, edgeColor);
      
      startAngle += sweepAngle;
      index++;
    }
  }
  
  void _drawSegmentEdge(Canvas canvas, double cx, double cy, double radius, 
      double scaleY, double startAngle, double sweepAngle, Color color) {
    final path = Path();
    
    // Only draw visible edges (front-facing)
    if (startAngle + sweepAngle > 0 && startAngle < math.pi) {
      final visibleStart = math.max(startAngle, 0.0);
      final visibleEnd = math.min(startAngle + sweepAngle, math.pi);
      final visibleSweep = visibleEnd - visibleStart;
      
      if (visibleSweep > 0) {
        // Top arc
        for (double a = visibleStart; a <= visibleEnd; a += 0.05) {
          final x = cx + radius * math.cos(a);
          final y = cy + radius * scaleY * math.sin(a);
          if (a == visibleStart) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        
        // Bottom arc (reversed)
        for (double a = visibleEnd; a >= visibleStart; a -= 0.05) {
          final x = cx + radius * math.cos(a);
          final y = cy + depth * animationValue + radius * scaleY * math.sin(a);
          path.lineTo(x, y);
        }
        
        path.close();
        
        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        
        canvas.drawPath(path, paint);
      }
    }
  }
  
  void _drawTopSurface(Canvas canvas, double cx, double cy, double radius, double scaleY, double total) {
    var startAngle = -math.pi / 2;
    int index = 0;
    
    for (final entry in data.entries) {
      final sweepAngle = (entry.value / total) * 2 * math.pi * animationValue;
      final color = colors[index % colors.length];
      final isHovered = index == hoveredIndex;
      
      // Hover effect - slightly larger
      final effectiveRadius = isHovered ? radius * 1.05 : radius;
      
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: effectiveRadius * 2,
        height: effectiveRadius * 2 * scaleY,
      );
      
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      
      // Draw subtle gradient overlay for premium look
      final gradientPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 1.2,
          colors: [
            Colors.white.withValues(alpha: 0.3),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.1),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect)
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(rect, startAngle, sweepAngle, true, gradientPaint);
      
      startAngle += sweepAngle;
      index++;
    }
    
    // Draw center circle (donut hole)
    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final holeRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: radius * 0.5,
      height: radius * 0.5 * scaleY,
    );
    
    canvas.drawOval(holeRect, holePaint);
    
    // Center circle shadow/depth
    final holeShadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.grey.shade300,
          Colors.grey.shade100,
          Colors.white,
        ],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(holeRect)
      ..style = PaintingStyle.fill;
    
    canvas.drawOval(holeRect, holeShadowPaint);
  }
  
  void _drawHighlights(Canvas canvas, double cx, double cy, double radius, double scaleY) {
    // Top highlight for glass effect
    final highlightPath = Path();
    final highlightRect = Rect.fromCenter(
      center: Offset(cx - radius * 0.2, cy - radius * scaleY * 0.2),
      width: radius * 0.8,
      height: radius * 0.4 * scaleY,
    );
    
    highlightPath.addOval(highlightRect);
    
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.4 * animationValue),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(highlightRect)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(highlightPath, highlightPaint);
  }
  
  @override
  bool shouldRepaint(covariant _PieChart3DPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.hoveredIndex != hoveredIndex;
  }
}

/// A card widget that displays a 3D pie chart with legend
class PieChart3DCard extends StatelessWidget {
  final String title;
  final Map<String, double> data;
  final bool isLoading;
  
  const PieChart3DCard({
    super.key,
    required this.title,
    required this.data,
    this.isLoading = false,
  });
  
  static const List<Color> _colors = [
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
  ];
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (isLoading) {
      return Card(
        child: SizedBox(
          height: 280,
          child: Center(
            child: CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }
    
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Sort and take top 5
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = Map.fromEntries(sortedEntries.take(5));
    final total = topEntries.values.fold(0.0, (sum, v) => sum + v);
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.pie_chart_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // 3D Pie Chart
                Expanded(
                  flex: 3,
                  child: Center(
                    child: PieChart3D(
                      data: topEntries,
                      colors: _colors,
                      size: 160,
                      depth: 18,
                      tilt: 0.35,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Legend
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: topEntries.entries.toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final percentage = total > 0 
                          ? ((item.value / total) * 100).toStringAsFixed(0) 
                          : '0';
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _colors[index % _colors.length],
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: _colors[index % _colors.length].withValues(alpha: 0.4),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.key,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '₹${_formatAmount(item.value)} ($percentage%)',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: (index * 100).ms).fadeIn().slideX(begin: 0.2);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
