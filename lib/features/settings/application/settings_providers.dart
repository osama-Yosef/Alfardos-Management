import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/money/money.dart';
import '../../../core/settings/company_settings.dart';
import '../../auth/application/auth_providers.dart';
import '../data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(firestoreProvider), ref.watch(storageProvider)),
);

final companySettingsStreamProvider = StreamProvider<CompanySettings>((ref) {
  if (ref.watch(currentUserProvider) == null) {
    return Stream.value(const CompanySettings());
  }
  return ref.watch(settingsRepositoryProvider).watch();
});

/// Current settings, falling back to defaults while loading.
final companySettingsProvider = Provider<CompanySettings>(
  (ref) => ref.watch(companySettingsStreamProvider).value ?? const CompanySettings(),
);

final moneyFormatterProvider = Provider<MoneyFormatter>((ref) {
  final s = ref.watch(companySettingsProvider);
  return MoneyFormatter(symbol: s.currencySymbol, decimals: s.decimals);
});
