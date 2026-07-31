/// Facts about the app that the About screen and its support links need.
abstract final class AppInfo {
  static const name = 'Mirror Logic';
  static const tagline = 'Reflect  •  Align  •  Solve';
  static const developer = 'Appware Tech';
  static const supportEmail = 'contact@appwaretech.com';

  /// Blurb under the crest on the About screen.
  static const summary =
      'An optical puzzle set in a candlelit keep. Turn the mirrors, bend the '
      'beam, and light every crystal.';

  /// Published privacy policy. Empty until one exists: the About screen hides
  /// the row rather than handing the player a dead link, and Play requires this
  /// to be reachable from the listing once the app ships with ads.
  static const privacyPolicyUrl = '';
}
