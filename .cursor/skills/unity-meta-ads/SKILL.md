---
name: unity-meta-ads
description: Replace AdMob with Unity Ads (first priority) and Meta Audience Network (fallback) in Flutter apps. Use when migrating ads, setting up banner/interstitial/rewarded waterfalls, or preventing invalid traffic and ad overlap.
paths:
  - "lib/infrastructure/ads/**"
  - "lib/core/constants/ad_unit_ids.dart"
  - "lib/app/ad_banner_host.dart"
  - "lib/presentation/widgets/ads/**"
  - "pubspec.yaml"
  - "android/app/src/main/AndroidManifest.xml"
  - "ios/Runner/Info.plist"
---

# Unity + Meta Ads (AdMob replacement)

## Goal

Serve **banner**, **interstitial**, and **rewarded** ads with:

1. **Unity Ads first** on every waterfall step
2. **Meta Audience Network second** when Unity has no fill
3. **Five slots per placement** (same count as AdMob waterfalls)
4. **No two ads visible at once** (full-screen mutex + hide banner during full-screen)
5. **Invalid-traffic safe** refresh and request rules

## Packages

```yaml
dependencies:
  unity_ads_plugin: ^0.4.0
  connectivity_plus: # keep — gate requests when offline
```

Do **not** add `google_mobile_ads` or any mediation adapter for Meta.
Do **not** use old/unmaintained Flutter Meta wrappers.

## Meta integration architecture (direct, no mediation)

Use direct Meta SDK integration via native Android Kotlin:

Flutter/Dart
→ `MethodChannel('meta_ads')` + Android PlatformView (`meta_banner_ad`)
→ `MetaAdsManager.kt` + `MetaBannerAdFactory.kt`
→ `com.facebook.android:audience-network-sdk`

### Required native pieces

- `android/app/src/main/kotlin/.../MetaAdsManager.kt`
  - initialize Meta SDK (idempotent)
  - load/show/dispose interstitial
  - load/show/dispose rewarded
  - enforce safe callbacks to Dart
- `android/app/src/main/kotlin/.../MetaBannerAdFactory.kt`
  - expose `AdView` banner as PlatformView
  - emit load/error callbacks through per-view MethodChannel
- `MainActivity.kt`
  - register `meta_ads` method channel handler
  - register `meta_banner_ad` view factory

### Required Dart bridge

- `lib/infrastructure/ads/meta_ads_bridge.dart`
  - `initialize({testMode})`
  - `loadInterstitial`, `isInterstitialReady`, `showInterstitial`
  - `loadRewarded`, `isRewardedReady`, `showRewarded`
  - `disposeInterstitial`, `disposeRewarded`

## ID structure (`ad_unit_ids.dart`)

Keep **5 slots × 3 placements** (banner, interstitial, rewarded), per platform:

```dart
class AdSlotIds {
  const AdSlotIds({required this.unity, required this.meta});
  final String unity; // Unity placement id
  final String meta;  // Meta placement id
}
```

Also store:

- `AdUnitIds.unityGameId` — platform-specific Unity game id
- `AdUnitIds.metaAppId` — Meta app id for native config

Use **example / test ids in debug** (`testMode: kDebugMode`). Replace all ids before release.

## Waterfall order

For each placement, for slot `0..4`:

1. Try **Unity** with `slot.unity`
2. If no fill → try **Meta** with `slot.meta`
3. If still no fill → next slot

Never fire Unity and Meta for the same impression in parallel.

## AdsService responsibilities

Central `AdsService` must keep the existing public API shape:

| Method | Behavior |
|--------|----------|
| `init()` | Init Unity + Meta; non-blocking at launch |
| `warmUp()` | Pre-cache interstitial + rewarded |
| `showInterstitial(policy:)` | Await dismiss; respect cadence + mutex |
| `showRewarded()` | Return `earned / skipped / unavailable`; pre-cache only |
| `bannerCandidates()` | Ordered list: Unity then Meta per slot |
| `claimFullScreenSlot()` / `releaseFullScreenSlot()` | Prevent interstitial + rewarded overlap |
| `isFullScreenAdShowing` | Banner host must hide while true |

### Full-screen load pattern

**Unity:** `UnityAds.load` → timeout per slot → `UnityAds.showVideoAd`

**Meta:** load/show through `MetaAdsBridge` (native Kotlin owns SDK objects and lifecycle)

### Full-screen show rules

- Only one full-screen ad at a time (mutex)
- Quiet period after any successful full-screen (`minGapBetweenFullScreenAds`, default 45s)
- Interstitial cadence: level clears + skip-first via Remote Config
- Rewarded: only show if pre-cached (`hasRewardedAd`)

## Banner pattern

Unity banners are Flutter widgets. Meta banners are native Android `AdView` rendered via PlatformView:

- `AdBannerHost` — single app-wide owner; route-gated (hide splash/onboarding)
- Walk `bannerCandidates()` until `onLoad` / `onLoaded`
- Load off-screen (`Offstage`) until filled; then show strip
- **Hide banner** when `isFullScreenAdShowing` or app backgrounded

### Invalid-traffic rules (banners)

- **Refresh interval ≥ 60 seconds** for manual remounts (Unity policy warns against aggressive auto-refresh abuse)
- **No requests when offline** (`connectivity_plus`)
- **No requests when app backgrounded**
- **No banner on splash / onboarding**
- Let SDK auto-refresh while visible; do not stack manual refresh on top faster than 60s

## Platform config

### Android `AndroidManifest.xml`

```xml
<meta-data android:name="com.facebook.sdk.ApplicationId" android:value="@string/facebook_app_id"/>
<meta-data android:name="com.facebook.sdk.ClientToken" android:value="@string/facebook_client_token"/>
```

`res/values/strings.xml` — real Meta app id + client token before release.

### Android Gradle

Use official Meta Audience Network Android SDK directly in app module:

```kotlin
implementation("com.facebook.android:audience-network-sdk:6.22.0")
```

Pin exact version and verify against official Meta docs/changelog before changing.

### iOS `Info.plist`

```xml
<key>FacebookAppID</key>
<string>YOUR_APP_ID</string>
<key>FacebookClientToken</key>
<string>YOUR_CLIENT_TOKEN</string>
<key>FacebookDisplayName</key>
<string>App Name</string>
<key>NSUserTrackingUsageDescription</key>
<string>...</string>
```

Remove `GADApplicationIdentifier`.

## Init snippet

```dart
UnityAds.init(
  gameId: AdUnitIds.unityGameId,
  testMode: kDebugMode,
  onComplete: () {},
  onFailed: (e, m) {},
);

await MetaAdsBridge.initialize(testMode: kDebugMode);
```

## Meta identifiers and secrets

- Do not confuse:
  - Business ID
  - Property ID
  - Ad Space ID
  - Developer App ID
  - Placement IDs
- The app must use **Developer App ID** + placement IDs.
- Never ship Meta App Secret in app code, assets, or config.

## Tests to preserve

- 5 slots per placement, non-empty ids
- Full-screen mutex (second claim refused)
- Interstitial cadence (level clears, quiet period, skip-first)
- Banner route gating
- SDK-not-ready → all show methods no-op

## Checklist before shipping

- [ ] Replace example Unity game id + 15 placement ids per platform
- [ ] Replace Meta app id, client token, 15 placement ids per platform
- [ ] `GameConstants.adsEnabled = true`
- [ ] `testMode: false` in release builds
- [ ] Update privacy policy (Unity + Meta, not AdMob)
- [ ] Verify no two ads overlap on device (banner + interstitial, interstitial + rewarded)
- [ ] Verify interstitial/rewarded callbacks: loaded, failed, shown, clicked, dismissed, reward-earned
- [ ] Ensure no aggressive retry or ad-request loops
- [ ] Ensure ad failures never block gameplay flow

## Reference implementation

See `mirror_logic` project:

- `lib/infrastructure/ads/ads_service.dart`
- `lib/core/constants/ad_unit_ids.dart`
- `lib/app/ad_banner_host.dart`
- `lib/presentation/widgets/ads/ad_banner_slot.dart`
