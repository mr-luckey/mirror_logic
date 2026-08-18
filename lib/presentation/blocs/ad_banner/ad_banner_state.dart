part of 'ad_banner_cubit.dart';

class AdBannerState extends Equatable {
  const AdBannerState({
    this.show = false,
    this.selection,
    this.bannerLoaded = false,
    this.mountGeneration = 0,
  });

  final bool show;
  final BannerAdSelection? selection;
  final bool bannerLoaded;
  final int mountGeneration;

  bool get visible => show && selection != null && bannerLoaded;

  bool get loading => show && selection != null && !bannerLoaded;

  AdBannerState copyWith({
    bool? show,
    BannerAdSelection? selection,
    bool clearSelection = false,
    bool? bannerLoaded,
    int? mountGeneration,
  }) {
    return AdBannerState(
      show: show ?? this.show,
      selection: clearSelection ? null : (selection ?? this.selection),
      bannerLoaded: bannerLoaded ?? this.bannerLoaded,
      mountGeneration: mountGeneration ?? this.mountGeneration,
    );
  }

  @override
  List<Object?> get props => [show, selection, bannerLoaded, mountGeneration];
}
