import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/speech_services.dart';

/// Production push-to-talk recognition backed by `speech_to_text`
/// (on-device/platform engine — no network AI service).
///
/// Every method is total: it catches plugin errors and always completes,
/// so voice interaction degrades to an error message instead of a crash
/// or a hang. Permission is requested lazily by [initialize], i.e. only
/// when the cashier first taps SPEAK — never at app startup.
class SttSpeechService implements SpeechToTextService {
  SttSpeechService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  String? _cachedLocaleId;
  bool _cachedAvailableLocales = false;
  bool _localeResolved = false;

  @override
  Future<bool> initialize() async {
    try {
      final available = await _speech.initialize();
      if (!available) return false;
      return await _speech.hasPermission;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> get hasPermission async {
    try {
      return await _speech.hasPermission;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> listenOnce() => listenOnceFor(preferredLocaleId: null);

  @override
  Future<String?> listenOnceFor({String? preferredLocaleId}) async {
    final localeId = await _resolveLocale(preferredLocaleId);
    final completer = Completer<String?>();
    void finish(String? value) {
      if (!completer.isCompleted) completer.complete(value);
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) finish(result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 3),
          partialResults: false,
          cancelOnError: true,
        ),
      );
    } catch (_) {
      finish(null);
    }

    try {
      final text = await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );
      if (text == null || text.trim().isEmpty) return null;
      return text;
    } finally {
      try {
        await _speech.stop();
      } catch (_) {}
    }
  }

  /// Resolves the locale to hand to `listen`. Prefers [preferredLocaleId],
  /// then a generic Indian fallback, then the device default. Caches the
  /// resolution across calls. Never throws.
  Future<String?> _resolveLocale(String? preferredLocaleId) async {
    if (_localeResolved) return _cachedLocaleId;
    try {
      final available = await _speech.locales();
      _cachedAvailableLocales = available.isNotEmpty;
      final ids = available.map((l) => l.localeId).toSet();

      String? best;
      // 1. Exact preferred locale.
      best = _findExact(ids, preferredLocaleId);
      // 2. Generic Indian preference if the exact one is missing.
      best ??= _findExact(ids, _generic(preferredLocaleId));
      // 3. Any hi/mr/en-IN fallback.
      best ??= _findAnyIndian(ids);
      // 4. Device default / null (recognizer picks).
      _cachedLocaleId = best;
      _localeResolved = true;
      return _cachedLocaleId;
    } catch (_) {
      _localeResolved = true;
      return null;
    }
  }

  String? _findExact(Set<String> ids, String? localeId) {
    if (localeId == null || localeId.isEmpty) return null;
    if (ids.contains(localeId)) return localeId;
    // Case-insensitive match on the language/region portion.
    final lower = localeId.toLowerCase();
    for (final id in ids) {
      if (id.toLowerCase() == lower) return id;
    }
    return null;
  }

  /// Maps a requested locale to a broader Indian locale for graceful
  /// fallback (e.g. "mr-IN" -> "hi-IN", "en-IN" stays, "hi-IN" stays).
  String? _generic(String? localeId) {
    if (localeId == null) return null;
    final lang = localeId.split('-').first.toLowerCase();
    return switch (lang) {
      'hi' || 'mr' => 'hi-IN',
      'en' => 'en-IN',
      _ => localeId,
    };
  }

  String? _findAnyIndian(Set<String> ids) {
    for (final candidate in const ['hi-IN', 'mr-IN', 'en-IN']) {
      final match = _findExact(ids, candidate);
      if (match != null) return match;
    }
    return null;
  }

  @override
  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }

  @visibleForTesting
  bool get hadAvailableLocales => _cachedAvailableLocales;
}
