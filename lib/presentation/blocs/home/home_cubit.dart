import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mirror_logic/domain/theme/theme_catalog.dart';

/// Home hall carousel page index — ColorZen-style, no setState.
class HomeCubit extends Cubit<int> {
  HomeCubit({required String selectedThemeId})
    : super(_indexOf(selectedThemeId));

  static int _indexOf(String themeId) {
    final i = ThemeCatalog.all.indexWhere((t) => t.id == themeId);
    if (i < 0) return 0;
    return i.clamp(0, ThemeCatalog.all.length - 1);
  }

  void setPage(int page) {
    final next = page.clamp(0, ThemeCatalog.all.length - 1);
    if (next == state) return;
    emit(next);
  }
}
