/// Which ad network filled or should serve a placement.
enum AdNetwork {
  /// Unity Ads — first priority in every waterfall step.
  unity,

  /// Meta Audience Network — fallback when Unity has no fill.
  meta,
}

/// A resolved banner the UI can mount.
///
/// Banner ads from Unity and Meta are widget-based, so the service only picks
/// the network and placement; [AdBannerSlot] renders the correct widget.
class BannerAdSelection {
  const BannerAdSelection({
    required this.network,
    required this.placementId,
    required this.slotIndex,
  });

  final AdNetwork network;
  final String placementId;

  /// Which waterfall slot produced this selection (0–4).
  final int slotIndex;

  /// Stable key for forcing a fresh widget when the strip refreshes.
  Object get mountKey => Object.hash(network, placementId, slotIndex);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BannerAdSelection &&
          network == other.network &&
          placementId == other.placementId &&
          slotIndex == other.slotIndex;

  @override
  int get hashCode => Object.hash(network, placementId, slotIndex);
}
