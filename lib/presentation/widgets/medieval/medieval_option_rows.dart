import 'package:flutter/material.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_pressable.dart';

/// A titled group of options on a bronze-framed panel.
///
/// Shared by Settings and About so the two screens read as one list of the same
/// kind of thing rather than two designs that happen to sit next to each other.
class MedievalSection extends StatelessWidget {
  const MedievalSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return MedievalPanel(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: MedievalColors.bronzeLight),
              const SizedBox(width: 7),
              Text(
                title.toUpperCase(),
                style: MedievalTextStyles.cinzel(
                  size: 11,
                  weight: FontWeight.w700,
                  letterSpacing: 2,
                  color: MedievalColors.textGold,
                ),
              ),
            ],
          ),
          const MedievalDivider(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// A row's name with an optional line of explanation under it.
class MedievalRowLabel extends StatelessWidget {
  const MedievalRowLabel({
    super.key,
    required this.label,
    this.note,
    this.danger = false,
  });

  final String label;
  final String? note;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: MedievalTextStyles.cinzel(
            size: Responsive.sp(context, 13.5),
            weight: FontWeight.w600,
            color: danger ? MedievalColors.rejectMid : MedievalColors.textCream,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 2),
          Text(
            note!,
            style: MedievalTextStyles.cinzel(
              size: Responsive.sp(context, 10.5),
              height: 1.3,
              color: MedievalColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// A tappable row that leads somewhere, with a chevron to say so.
class MedievalLinkRow extends StatelessWidget {
  const MedievalLinkRow({
    super.key,
    required this.label,
    required this.onTap,
    this.note,
    this.danger = false,
  });

  final String label;
  final String? note;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return MedievalPressable(
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              child: MedievalRowLabel(label: label, note: note, danger: danger),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: danger
                  ? MedievalColors.rejectMid.withValues(alpha: 0.8)
                  : MedievalColors.bronzeLight.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row that only states a fact, like a version number.
class MedievalInfoRow extends StatelessWidget {
  const MedievalInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(child: MedievalRowLabel(label: label)),
          const SizedBox(width: 12),
          Text(
            value,
            style: MedievalTextStyles.cinzelDecorative(
              size: Responsive.sp(context, 12.5),
              weight: FontWeight.w700,
              color: MedievalColors.bronzeHighlight,
            ),
          ),
        ],
      ),
    );
  }
}
