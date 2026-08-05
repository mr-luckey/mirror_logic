---
name: Theme Preview Rewards
overview: Home carousel will preview every visible hall theme, while only owned halls are persisted/equipped. Insufficient theme purchases will open a BLoC-driven earn dialog with Continue and rewarded-ad actions, a persistent 20-ad/24-hour quota, and 5 coins per earned ad.
todos:
  - id: carousel-preview
    content: Restore settled-page live theme preview and hide Chapters for locked halls
    status: completed
  - id: reward-domain
    content: Add persistent 20-per-24h rewarded coin accounting
    status: completed
  - id: reward-bloc
    content: Implement and provide the no-setState rewarded coins Cubit
    status: completed
  - id: purchase-dialog
    content: Build insufficient-coins dialog with Continue and Watch Ad actions
    status: completed
  - id: verification
    content: Add tests and run formatter, analyzer, and test suite
    status: completed
isProject: false
---

# Theme preview and rewarded coins

## 1. Restore live carousel theme previews
- Update [`lib/presentation/screens/main_menu/main_menu_screen.dart`](lib/presentation/screens/main_menu/main_menu_screen.dart) so each settled carousel page calls the existing `ThemeCubit.previewHall(themeId)` for immediate full-screen color/art preview, including locked halls.
- Continue calling `equipFromCarousel` only for owned themes, so previews do not unlock or persist locked halls.
- Hide the Chapters button entirely when the visible hall is locked; keep the current Play lock behavior unchanged.

## 2. Persist and manage the rewarded-ad quota through BLoC
- Extend [`lib/domain/economy/player_save.dart`](lib/domain/economy/player_save.dart) with backward-compatible rewarded-ad count/window fields and JSON support.
- Preserve those fields during progress reset in [`lib/data/repositories/save_repository.dart`](lib/data/repositories/save_repository.dart).
- Set reward constants in [`lib/core/constants/game_constants.dart`](lib/core/constants/game_constants.dart) to 5 coins, 20 ads, and a 24-hour window starting from the first successfully rewarded ad.
- Add an atomic reward operation in [`lib/data/repositories/economy_repository.dart`](lib/data/repositories/economy_repository.dart) so one persisted save increments both coins and ad count without stale-write races.
- Add a global `RewardedCoinsCubit` under [`lib/presentation/blocs/economy/`](lib/presentation/blocs/economy/) and provide it from [`lib/main.dart`](lib/main.dart). It will own loading, expiry normalization, ad-in-progress locking, AdMob outcomes, quota enforcement, and success/error states—no `setState`.

## 3. Add the insufficient-coins popup
- Update [`lib/presentation/screens/theme_shop/theme_shop_screen.dart`](lib/presentation/screens/theme_shop/theme_shop_screen.dart) so an unaffordable Buy button remains tappable and opens a medieval-styled dialog showing theme price, current coins, and missing coins.
- Add two actions:
  - `Play Game`: close the shop flow and open the same saved level used by Home’s Play/Continue action, retaining the currently equipped/owned theme.
  - `Watch Ad to Earn`: include an ad icon, show `watched/20`, award 5 coins only for `RewardedAdOutcome.earned`, and keep balance/theme state synchronized so purchase becomes available immediately.
- Keep the dialog reactive with Bloc builders/listeners; show clear unavailable/skipped/limit feedback without changing unrelated theme-shop behavior.

## 4. Verify behavior
- Add focused tests for old-save defaults, persistence across restart/reset, first-ad window creation, 20-ad cap, exact 24-hour reset, 5-coin atomic grants, skipped/unavailable ads, and duplicate-tap protection.
- Add ThemeCubit/home assertions where practical for preview-vs-persist behavior and locked Chapters visibility.
- Run formatting, Flutter analysis, and the relevant/full test suite.