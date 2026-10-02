import 'package:flutter/material.dart';

class MetricCard extends StatefulWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isActive;
  final VoidCallback onTap;

  const MetricCard({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.isActive = false,
    required this.onTap,
  });

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = widget.isActive
        ? widget.color
        : (_isHovered
            ? widget.color.withOpacity(0.8)
            : (isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0)));

    final cardBg = isDark
        ? (_isHovered ? const Color(0xFF1B243B) : const Color(0xFF151D2F))
        : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.identity()..translate(0.0, _isHovered ? -2.0 : 0.0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: widget.isActive ? 2 : (_isHovered ? 1.5 : 1),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isActive || _isHovered
                    ? widget.color.withOpacity(isDark ? 0.25 : 0.15)
                    : Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                blurRadius: _isHovered ? 14 : 8,
                offset: Offset(0, _isHovered ? 5 : 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: widget.color.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.count.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
