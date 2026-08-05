abstract final class GameConstants {
  static const int maxBounces = 24;
  static const double holdTimeSeconds = 0.4;
  static const double defaultHitRadius = 40;
  static const double roomWidth = 1080;
  static const double roomHeight = 1920;
  static const double angleToleranceDegrees = 4;

  /// Flat reward for clearing a level, regardless of stars.
  static const int coinsPerLevel = 5;

  /// Price of revealing the solved board. One hint, one price — no free tier,
  /// so coin always has somewhere to go.
  static const int hintCost = 25;

  /// Height of the banner strip along the bottom of the app.
  ///
  /// Held open whether or not an ad is serving, so a fill that arrives mid-drag
  /// never moves the board out from under the player's finger. Comfortably
  /// clears the 50pt standard banner the strip asks for.
  static const double adBannerHeight = 56;

  /// Stars the player must hold in a chapter before the next one opens.
  ///
  /// A chapter is 100 levels worth three stars each, so this is the full
  /// chapter total — every level has to be cleared at three stars.
  static const int starsToUnlockNextChapter = 300;

  /// Set to false before shipping. When true, all chapters/levels are playable.
  static const bool unlockAllLevelsForTesting = false;

  /// Rewarded-ad coin grant (wired later — ads stay off until then).
  static const int coinsPerRewardedAd = 15;

  /// Set to true before shipping. When false, ads never init, load, or show.
  static const bool adsEnabled = true;

  static const String chapter1Id = 'ch1';
  static const String chapter2Id = 'ch2';

  /// Seed level for a fresh save.
  static const String firstLevelId = 'ch1_001';

  /// Continuous display number: ch2 level 1 is 101, ch3 level 1 is 201…
  static int displayLevelNumber(String chapterId, int levelIndex) {
    final n = int.tryParse(chapterId.replaceFirst('ch', '')) ?? 1;
    return (n - 1) * 100 + levelIndex;
  }
}
