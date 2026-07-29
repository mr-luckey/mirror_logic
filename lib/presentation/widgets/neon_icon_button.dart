import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';
import 'package:mirror_logic/core/utils/responsive.dart';

class NeonIconButton extends StatelessWidget {
  const NeonIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
    this.badge,
    this.size,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;
  final String? badge;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final buttonSize =
        (size ?? Responsive.sp(context, 52)).clamp(40.0, 56.0);
    final labelSize = Responsive.sp(context, 11).clamp(10.0, 13.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.panel.withValues(alpha: 0.8),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: Icon(
                    icon,
                    color: AppColors.textPrimary,
                    size: buttonSize * 0.42,
                  ),
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentButton,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: labelSize - 1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (label != null) ...[
          SizedBox(height: Responsive.isShort(context) ? 4 : 6),
          Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: labelSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
