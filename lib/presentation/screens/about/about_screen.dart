import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:mirror_logic/app/review_scope.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';
import 'package:mirror_logic/core/constants/app_info.dart';
import 'package:mirror_logic/core/utils/responsive.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_art.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_option_rows.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_panel.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_screen_header.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_toast.dart';
import 'package:mirror_logic/presentation/widgets/medieval/medieval_wood_background.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mirror_logic/domain/theme/theme_controller.dart';

/// Who made the game, which build this is, and how to reach anyone about it.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  /// The version comes from the platform, so it is absent in a widget test and
  /// on any host without the plugin. The row is simply left out in that case.
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = '${info.version} (${info.buildNumber})');
    } catch (error) {
      debugPrint('package info unavailable: $error');
    }
  }

  Future<void> _rate() async {
    final review = context.review;
    if (review == null) return;
    // Settled here even though the store may not open: a player who came all
    // the way to About and tapped Rate should not also meet the random prompt.
    await review.markSettled();
    final opened = await review.promptForRating();
    if (!opened && mounted) {
      MedievalToast.show(context, 'Could not open the Play Store');
    }
  }

  Future<void> _email() async {
    await _open(
      Uri(
        scheme: 'mailto',
        path: AppInfo.supportEmail,
        queryParameters: {'subject': '${AppInfo.name} — feedback'},
      ),
    );
  }

  Future<bool> _open(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        MedievalToast.show(context, 'Nothing on this device can open that');
      }
      return ok;
    } catch (error) {
      debugPrint('launch failed for $uri: $error');
      if (mounted) {
        MedievalToast.show(context, 'Nothing on this device can open that');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    final gutter = Responsive.pageGutter(context);
    final short = Responsive.isShort(context);
    final crest = Responsive.wp(
      context,
      short ? 0.26 : 0.32,
    ).clamp(96.0, 150.0);

    return Material(
      type: MaterialType.transparency,
      child: MedievalWoodBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: MedievalScreenHeader(
                  title: 'About Us',
                  subtitle: 'Who keeps the light',
                  onBack: () => context.pop(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 24),
                  children: [
                    _Masthead(crestSize: crest),
                    const SizedBox(height: 13),
                    MedievalSection(
                      title: 'The Keep',
                      icon: Icons.auto_stories_rounded,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            AppInfo.summary,
                            style: MedievalTextStyles.cinzel(
                              size: Responsive.sp(context, 12),
                              height: 1.5,
                              color: MedievalColors.textCream.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ),
                        const MedievalDivider(),
                        MedievalInfoRow(
                          label: 'Made By',
                          value: AppInfo.developer,
                        ),
                        if (_version != null) ...[
                          const MedievalDivider(),
                          MedievalInfoRow(label: 'Version', value: _version!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 13),
                    MedievalSection(
                      title: 'Support The Game',
                      icon: Icons.favorite_rounded,
                      children: [
                        MedievalLinkRow(
                          label: 'Rate ${AppInfo.name}',
                          note: 'Leave a review on Google Play',
                          onTap: _rate,
                        ),
                        const MedievalDivider(),
                        MedievalLinkRow(
                          label: 'Contact Us',
                          note: AppInfo.supportEmail,
                          onTap: _email,
                        ),
                        if (AppInfo.privacyPolicyUrl.isNotEmpty) ...[
                          const MedievalDivider(),
                          MedievalLinkRow(
                            label: 'Privacy Policy',
                            onTap: () =>
                                _open(Uri.parse(AppInfo.privacyPolicyUrl)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '© ${DateTime.now().year} ${AppInfo.developer}',
                      textAlign: TextAlign.center,
                      style: MedievalTextStyles.cinzel(
                        size: Responsive.sp(context, 10.5),
                        letterSpacing: 1.4,
                        color: MedievalColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The crest, the name and the tagline, as the screen's opening statement.
class _Masthead extends StatelessWidget {
  const _Masthead({required this.crestSize});

  final double crestSize;

  @override
  Widget build(BuildContext context) {
    ThemeController.watch(context);
    return Column(
      children: [
        MedievalArtwork(
              asset: MedievalArt.crest,
              size: crestSize,
              glow: MedievalColors.laserGlow,
              glowStrength: 0.24,
            )
            .animate()
            .fadeIn(duration: 450.ms)
            .scale(begin: const Offset(0.92, 0.92)),
        const SizedBox(height: 12),
        Text(
          AppInfo.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: MedievalTextStyles.cinzelDecorative(
            size: Responsive.sp(context, 22),
            weight: FontWeight.w700,
            letterSpacing: 2,
            color: MedievalColors.textGold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppInfo.tagline,
          textAlign: TextAlign.center,
          style: MedievalTextStyles.cinzel(
            size: Responsive.sp(context, 11),
            letterSpacing: 2,
            color: MedievalColors.textMuted,
          ),
        ),
      ],
    );
  }
}
