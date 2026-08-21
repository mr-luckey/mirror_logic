/// Facts about the app that the About screen and its support links need.
abstract final class AppInfo {
  static const name = 'Mirror Logic';
  static const tagline = 'Reflect  •  Align  •  Solve';
  static const developer = 'Appware Tech';
  static const supportEmail = 'contact@appwaretech.com';

  /// Play listing id. Must match `applicationId` in android/app/build.gradle.kts
  /// — the rate links resolve to nothing if the two drift apart.
  static const playStoreId = 'com.appwaretech.mirrorlogic';

  /// Blurb under the crest on the About screen.
  static const summary =
      'An optical puzzle set in a candlelit keep. Turn the mirrors, bend the '
      'beam, and light every crystal.';

  /// Hosted privacy policy (Unity Ads + Meta Audience Network). Required on
  /// the Play listing when the binary serves ads.
  static const privacyPolicyUrl =
      'https://raw.githubusercontent.com/mr-luckey/mirror_logic/main/mirror_logic-PRIVACY_POLICY.txt';
}
