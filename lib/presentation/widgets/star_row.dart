import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';

class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.filled,
    this.size = 22,
    this.total = 3,
  });

  final int filled;
  final double size;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i < filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            active ? Icons.star_rounded : Icons.star_outline_rounded,
            color: active ? AppColors.gold : AppColors.muted,
            size: size,
            shadows: active
                ? [
                    Shadow(
                      color: AppColors.gold.withValues(alpha: 0.8),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class CurrencyChip extends StatelessWidget {
  const CurrencyChip({
    super.key,
    required this.coins,
    this.onAdd,
  });

  final int coins;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: AppColors.gold, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$coins',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 2),
            GestureDetector(
              onTap: onAdd,
              child: const Icon(
                Icons.add_circle,
                color: AppColors.gold,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
