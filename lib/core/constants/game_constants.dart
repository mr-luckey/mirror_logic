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

  static const int hintTier1Cost = 10;
  static const int hintTier2Cost = 20;
  static const int hintTier3Cost = 30;
  static const int freeHintLevels = 10;

  static const double chapterUnlockRatio = 0.8;

  /// Set to false before shipping. When true, all chapters/levels are playable.
  static const bool unlockAllLevelsForTesting = true;

  static const String chapter1Id = 'ch1';
  static const String chapter2Id = 'ch2';

  /// Seed level for a fresh save.
  static const String firstLevelId = 'ch1_001';
}
