import 'package:hive_flutter/hive_flutter.dart';
import 'package:mirror_logic/data/repositories/economy_repository.dart';
import 'package:mirror_logic/data/repositories/level_repository.dart';
import 'package:mirror_logic/data/repositories/save_repository.dart';
import 'package:mirror_logic/infrastructure/ads/ads_remote_config.dart';
import 'package:mirror_logic/infrastructure/ads/ads_service.dart';
import 'package:mirror_logic/infrastructure/audio/audio_service.dart';
import 'package:mirror_logic/infrastructure/review/review_service.dart';
import 'package:mirror_logic/infrastructure/storage/local_storage_service.dart';
import 'package:mirror_logic/infrastructure/update/app_update_service.dart';

final Map<Type, Object> _services = {};

T sl<T extends Object>() {
  final service = _services[T];
  if (service == null) {
    throw StateError('Service $T not registered');
  }
  return service as T;
}

Future<void> configureDependencies() async {
  final box = await Hive.openBox<dynamic>('mirror_logic');
  final storage = LocalStorageService(box);
  final saveRepository = SaveRepository(storage);
  final economyRepository = EconomyRepository(saveRepository);
  final levelRepository = LevelRepository();
  final audioService = AudioService();
  final adsRemoteConfig = AdsRemoteConfig.instance;
  final adsService = AdsService(remoteConfig: adsRemoteConfig);
  final reviewService = ReviewService(storage: storage);
  final updateService = AppUpdateService(storage: storage);

  _services[LocalStorageService] = storage;
  _services[SaveRepository] = saveRepository;
  _services[EconomyRepository] = economyRepository;
  _services[LevelRepository] = levelRepository;
  _services[AudioService] = audioService;
  _services[AdsRemoteConfig] = adsRemoteConfig;
  _services[AdsService] = adsService;
  _services[ReviewService] = reviewService;
  _services[AppUpdateService] = updateService;
}
