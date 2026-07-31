abstract final class GameConstants {
  static const int maxBounces = 24;
  static const double holdTimeSeconds = 0.4;
  static const double defaultHitRadius = 40;
  static const double roomWidth = 1080;
  static const double roomHeight = 1920;
  static const double angleToleranceDegrees = 4;

  static const int coinsPerOneStar = 5;
  static const int coinsPerTwoStar = 10;
  static const int coinsPerThreeStar = 20;

  /// Price of revealing the solved board. One hint, one price.
  static const int hintCost = 25;

  /// Hints are free while the player is still learning the rules.
  static const int freeHintLevels = 10;

  static const double chapterUnlockRatio = 0.8;

  /// Set to false before shipping. When true, all chapters/levels are playable.
  static const bool unlockAllLevelsForTesting = true;

  static const String chapter1Id = 'ch1';
  static const String chapter2Id = 'ch2';

  /// Seed level for a fresh save.
  static const String firstLevelId = 'ch1_001';
}
