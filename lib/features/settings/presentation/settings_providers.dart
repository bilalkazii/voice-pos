import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/errors/failures.dart';
import '../../products/presentation/products_providers.dart';
import '../../voice/domain/voice_language.dart';
import '../data/settings_repository_impl.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

final settingsDaoProvider = Provider(
  (ref) => ref.watch(databaseProvider).settingsDao,
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => DriftSettingsRepository(ref.watch(settingsDaoProvider)),
);

/// Live app settings; emits on every persisted change. Starts at stable
/// defaults until the database row values arrive.
final settingsProvider = StreamProvider<AppSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).watch();
});

/// Configured store name for receipts, falling back to the app default
/// while settings load. Historical Sale/SaleItem rows are never modified —
/// this is presentation-time configuration only.
final storeNameProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).maybeWhen(
        data: (s) => s.storeName,
        orElse: () => AppConstants.defaultStoreName,
      );
});

/// Default threshold stamped onto NEW products at creation time. Existing
/// products keep their own thresholds — this never mass-updates anything.
final defaultLowStockThresholdProvider = Provider<int>((ref) {
  return ref.watch(settingsProvider).maybeWhen(
        data: (s) => s.defaultLowStockThreshold,
        orElse: () => AppSettings.defaults.defaultLowStockThreshold,
      );
});

/// Selected voice command language (English default while loading).
final voiceLanguageProvider = Provider<VoiceLanguage>((ref) {
  return ref.watch(settingsProvider).maybeWhen(
        data: (s) => s.voiceLanguage,
        orElse: () => AppSettings.defaults.voiceLanguage,
      );
});

/// Settings mutations. Each method guards against concurrent duplicate
/// saves and returns the [Failure] to display (null on success); the
/// [settingsProvider] stream updates the UI automatically.
class SettingsController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  bool get _busy => state is AsyncLoading;

  Future<Failure?> saveStoreName(String name) async {
    if (_busy) return null;
    state = const AsyncLoading();
    try {
      await ref.read(settingsRepositoryProvider).saveStoreName(name);
      state = const AsyncData(null);
      return null;
    } on Failure catch (e) {
      state = AsyncError(e, StackTrace.current);
      return e;
    } catch (e) {
      const failure =
          DatabaseFailure(message: 'Could not save settings.');
      state = AsyncError(failure, StackTrace.current);
      return failure;
    }
  }

  Future<Failure?> setVoiceFeedbackEnabled(bool enabled) async {
    if (_busy) return null;
    state = const AsyncLoading();
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setVoiceFeedbackEnabled(enabled);
      state = const AsyncData(null);
      return null;
    } on Failure catch (e) {
      state = AsyncError(e, StackTrace.current);
      return e;
    } catch (_) {
      const failure =
          DatabaseFailure(message: 'Could not save settings.');
      state = AsyncError(failure, StackTrace.current);
      return failure;
    }
  }

  Future<Failure?> setVoiceLanguage(VoiceLanguage language) async {
    if (_busy) return null;
    state = const AsyncLoading();
    try {
      await ref.read(settingsRepositoryProvider).setVoiceLanguage(language);
      state = const AsyncData(null);
      return null;
    } on Failure catch (e) {
      state = AsyncError(e, StackTrace.current);
      return e;
    } catch (_) {
      const failure =
          DatabaseFailure(message: 'Could not save settings.');
      state = AsyncError(failure, StackTrace.current);
      return failure;
    }
  }

  Future<Failure?> setDefaultLowStockThreshold(int threshold) async {
    if (_busy) return null;
    state = const AsyncLoading();
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setDefaultLowStockThreshold(threshold);
      state = const AsyncData(null);
      return null;
    } on Failure catch (e) {
      state = AsyncError(e, StackTrace.current);
      return e;
    } catch (_) {
      const failure =
          DatabaseFailure(message: 'Could not save settings.');
      state = AsyncError(failure, StackTrace.current);
      return failure;
    }
  }

  /// Persists the selected Bluetooth printer (address + display name) as
  /// one atomic selection. Returns the [Failure] to display, if any.
  Future<Failure?> savePrinterSelection({
    required String address,
    required String name,
  }) async {
    if (_busy) return null;
    state = const AsyncLoading();
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setPrinterSelection(id: address, name: name);
      state = const AsyncData(null);
      return null;
    } on Failure catch (e) {
      state = AsyncError(e, StackTrace.current);
      return e;
    } catch (_) {
      const failure =
          DatabaseFailure(message: 'Could not save printer.');
      state = AsyncError(failure, StackTrace.current);
      return failure;
    }
  }

  /// Clears the configured printer back to unconfigured.
  Future<Failure?> forgetPrinter() async {
    if (_busy) return null;
    state = const AsyncLoading();
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setPrinterSelection(id: null, name: null);
      state = const AsyncData(null);
      return null;
    } on Failure catch (e) {
      state = AsyncError(e, StackTrace.current);
      return e;
    } catch (_) {
      const failure =
          DatabaseFailure(message: 'Could not forget printer.');
      state = AsyncError(failure, StackTrace.current);
      return failure;
    }
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AsyncValue<void>>(
  SettingsController.new,
);
