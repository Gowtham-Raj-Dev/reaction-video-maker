import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// A gradient, scale-on-tap primary button with icon + label. Never looks like
/// a default Material button.
class PremiumButton extends StatefulWidget {
  const PremiumButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.gradient = AppColors.brandGradient,
    this.busy = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Gradient gradient;
  final bool busy;
  final bool compact;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.gradient.colors.first;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.busy
          ? null
          : () {
              Haptics.tap();
              widget.onTap();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: AppSpacing.fast,
        curve: AppSpacing.spring,
        child: AnimatedContainer(
          duration: AppSpacing.fast,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 16 : 22,
            vertical: widget.compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: _pressed ? 0.25 : 0.45),
                blurRadius: _pressed ? 10 : 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              else if (widget.icon != null)
                Icon(widget.icon, size: 18, color: Colors.white),
              if ((widget.icon != null || widget.busy)) const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compact ? 13 : 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small circular glass icon button used in toolbars.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
    this.active = false,
    this.tint,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final bool active;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = active ? (tint ?? AppColors.accent) : AppColors.textSecondary;
    return InkResponse(
      onTap: () {
        Haptics.selection();
        onTap();
      },
      radius: 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppSpacing.fast,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active
                  ? (tint ?? AppColors.accent).withValues(alpha: 0.16)
                  : AppColors.glassFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? (tint ?? AppColors.accent).withValues(alpha: 0.5)
                    : AppColors.stroke,
              ),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          if (label != null) ...[
            const SizedBox(height: 5),
            Text(
              label!,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
