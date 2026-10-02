import 'voice_command.dart';
import 'voice_language.dart';
import 'voice_vocabulary.dart';

/// Deterministic, rule-based voice command parser. No LLM, no network.
///
/// Design bias: predictable FALSE NEGATIVES over dangerous false positives.
/// An utterance the parser cannot confidently map becomes [UnknownCommand],
/// which never mutates the cart.
///
/// Two parsing paths share one [VoiceCommand] model:
/// - English keeps the batte-tested regex path.
/// - Hindi / Marathi / Hinglish use a vocabulary-driven, token-aware
///   extractor backed by [VoiceVocabulary].
///
/// Product names are preserved verbatim (never translated/transliterated).
/// Numbers: digits plus spoken words 1–20 in English, Hindi, Marathi, and
/// Roman Hinglish. Anything more complex yields [UnknownCommand].
class CommandParser {
  const CommandParser();

  /// Parses a transcript for a [language]. Defaults to English so existing
  /// callers and English tests keep working unchanged.
  VoiceCommand parse(
    String transcript, {
    VoiceLanguage language = VoiceLanguage.english,
  }) {
    final text = _normalize(transcript);
    if (text.isEmpty) return const UnknownCommand('');

    if (language == VoiceLanguage.english) {
      return _parseEnglish(text, transcript);
    }
    return _parseMultilingual(text, transcript, language);
  }

  // ---------------------------------------------------------------------
  // English (existing regex path)
  // ---------------------------------------------------------------------

  static const Map<String, int> numberWords = {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'a': 1,
    'an': 1,
  };

  /// Parses a single spoken quantity token (digits or one number word).
  /// Returns null when it cannot be confidently parsed. Range 0–999.
  static int? tryParseQuantity(String token) {
    final t = token.trim().toLowerCase();
    if (numberWords.containsKey(t)) return numberWords[t];
    final n = int.tryParse(t);
    if (n == null || n < 0 || n > 999) return null;
    return n;
  }

  /// Parses a quantity token across all supported number vocabularies.
  /// Returns null when not confidently a quantity. Range 0–999.
  static int? tryParseQuantityAnyLanguage(String token) {
    final t = token.trim().toLowerCase();
    if (numberWords.containsKey(t)) return numberWords[t];
    if (VoiceVocabulary.hindiNumbers.containsKey(t)) {
      return VoiceVocabulary.hindiNumbers[t];
    }
    if (VoiceVocabulary.marathiNumbers.containsKey(t)) {
      return VoiceVocabulary.marathiNumbers[t];
    }
    if (VoiceVocabulary.romanNumbers.containsKey(t)) {
      return VoiceVocabulary.romanNumbers[t];
    }
    final n = int.tryParse(t);
    if (n == null || n < 0 || n > 999) return null;
    return n;
  }

  VoiceCommand _parseEnglish(String text, String raw) {
    if (text == 'checkout' || text == 'check out') {
      return const CheckoutCommand();
    }
    if (RegExp(r'^(clear|empty)( the| my)? cart$').hasMatch(text)) {
      return const ClearCartCommand();
    }

    final add = _parseAddEnglish(text);
    if (add != null) return add;
    final remove = _parseRemoveEnglish(text);
    if (remove != null) return remove;
    final increase = _parseAdjustEnglish(text, 'increase');
    if (increase != null) return increase;
    final decrease = _parseAdjustEnglish(text, 'decrease');
    if (decrease != null) return decrease;
    final setQty = _parseSetQuantityEnglish(text);
    if (setQty != null) return setQty;

    final price = _parsePriceEnglish(text);
    if (price != null) return price;
    final stock = _parseStockEnglish(text);
    if (stock != null) return stock;

    return UnknownCommand(raw.trim());
  }

  VoiceCommand? _parseAddEnglish(String text) {
    final match = RegExp(r'^add\s+(.+)$').firstMatch(text);
    if (match == null) return null;
    final rest = match.group(1)!.trim();
    final tokens = rest.split(' ');
    final qty = tryParseQuantity(tokens.first);
    if (qty != null) {
      if (tokens.length < 2) return UnknownCommand(text);
      if (tryParseQuantity(tokens[1]) != null) return UnknownCommand(text);
      final name = _stripToCart(tokens.sublist(1).join(' '));
      if (name.isEmpty) return UnknownCommand(text);
      return AddProductCommand(productName: name, quantity: qty);
    }
    final name = _stripToCart(rest);
    if (name.isEmpty) return UnknownCommand(text);
    return AddProductCommand(productName: name, quantity: 1);
  }

  VoiceCommand? _parseRemoveEnglish(String text) {
    final match = RegExp(r'^remove\s+(.+)$').firstMatch(text);
    if (match == null) return null;
    final rest = match.group(1)!.trim();
    final tokens = rest.split(' ');
    final qty = tryParseQuantity(tokens.first);
    if (qty != null) {
      if (tokens.length < 2) return UnknownCommand(text);
      if (tryParseQuantity(tokens[1]) != null) return UnknownCommand(text);
      final name = _stripToCart(tokens.sublist(1).join(' '));
      if (name.isEmpty) return UnknownCommand(text);
      return RemoveProductCommand(productName: name, quantity: qty);
    }
    final name = _stripToCart(rest);
    if (name.isEmpty) return UnknownCommand(text);
    return RemoveProductCommand(productName: name);
  }

  VoiceCommand? _parseAdjustEnglish(String text, String verb) {
    final match = RegExp('^$verb\\s+(.+)\$').firstMatch(text);
    if (match == null) return null;
    var rest = _stripToCart(match.group(1)!.trim());
    var quantity = 1;
    final byMatch = RegExp(r'^(.+?)\s+by\s+(.+)$').firstMatch(rest);
    if (byMatch != null) {
      final qty = tryParseQuantity(byMatch.group(2)!.trim());
      if (qty == null) return UnknownCommand(text);
      quantity = qty;
      rest = byMatch.group(1)!.trim();
    }
    if (rest.isEmpty || rest == 'by' || rest.startsWith('by ')) {
      return UnknownCommand(text);
    }
    return verb == 'increase'
        ? IncreaseProductCommand(productName: rest, quantity: quantity)
        : DecreaseProductCommand(productName: rest, quantity: quantity);
  }

  VoiceCommand? _parseSetQuantityEnglish(String text) {
    final match =
        RegExp(r'^(make|set|change)\s+(.+?)\s+(?:quantity|qty)\s+(?:to\s+|is\s+)?(.+)$')
            .firstMatch(text);
    if (match == null) return null;
    final name = match.group(2)!.trim();
    final qty = tryParseQuantity(match.group(3)!.trim());
    if (name.isEmpty || qty == null) return UnknownCommand(text);
    return SetQuantityCommand(productName: name, quantity: qty);
  }

  VoiceCommand? _parsePriceEnglish(String text) {
    final patterns = [
      RegExp(r'^(whats|what is) the price of (.+)$'),
      RegExp(r'^how much is (.+)$'),
      RegExp(r'^how much does (.+) cost$'),
      RegExp(r'^price of (.+)$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final name = match.group(match.groupCount)!.trim();
        if (name.isEmpty) return UnknownCommand(text);
        return PriceQueryCommand(productName: name);
      }
    }
    return null;
  }

  VoiceCommand? _parseStockEnglish(String text) {
    final howMany = RegExp(r'^how many (.+?) in stock$').firstMatch(text);
    if (howMany != null) {
      final name = _stripAux(howMany.group(1)!);
      if (name.isEmpty) return UnknownCommand(text);
      return StockQueryCommand(productName: name);
    }
    final howMuch = RegExp(r'^how much (.+?) (is |are )?left$').firstMatch(text);
    if (howMuch != null) {
      final name = _stripAux(howMuch.group(1)!);
      if (name.isEmpty) return UnknownCommand(text);
      return StockQueryCommand(productName: name);
    }
    final bare = RegExp(r'^(.+) stock$').firstMatch(text);
    if (bare != null) {
      final name = bare.group(1)!.trim();
      if (name.isEmpty) return UnknownCommand(text);
      return StockQueryCommand(productName: name);
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Multilingual (Hindi / Marathi / Hinglish)
  // ---------------------------------------------------------------------

  VoiceCommand _parseMultilingual(
    String text,
    String raw,
    VoiceLanguage language,
  ) {
    if (_matchesAnyToken(text, _checkoutMarks(language))) {
      return const CheckoutCommand();
    }
    if (_matchesAnyToken(text, _clearMarks(language))) {
      return const ClearCartCommand();
    }

    final setQty = _parseSetQuantityMulti(text, language);
    if (setQty != null) return setQty;

    final tokens = text.split(' ');

    final add = _parseAddMulti(tokens, text, language);
    if (add != null) return add;
    final remove = _parseRemoveMulti(tokens, text, language);
    if (remove != null) return remove;

    final price = _parsePriceMulti(text, language);
    if (price != null) return price;
    final stock = _parseStockMulti(text, language);
    if (stock != null) return stock;

    return UnknownCommand(raw.trim());
  }

  List<String> _checkoutMarks(VoiceLanguage l) => switch (l) {
        VoiceLanguage.hindi => VoiceVocabulary.checkoutHindi,
        VoiceLanguage.marathi => VoiceVocabulary.checkoutMarathi,
        _ => VoiceVocabulary.checkoutHinglish,
      };

  List<String> _clearMarks(VoiceLanguage l) => switch (l) {
        VoiceLanguage.hindi => VoiceVocabulary.clearHindi,
        VoiceLanguage.marathi => VoiceVocabulary.clearMarathi,
        _ => VoiceVocabulary.clearHinglish,
      };

  /// ADD: `"<quantity> <product> <verb>"` or `"<verb> <quantity> <product>"`.
  VoiceCommand? _parseAddMulti(
    List<String> tokens,
    String text,
    VoiceLanguage language,
  ) {
    if (!_hasAddMark(text, language)) return null;
    final qty = _extractQuantity(tokens);
    final product = _extractProduct(tokens, _addDropSet(language));
    if (product == null || product.isEmpty) return null;
    return AddProductCommand(
      productName: product,
      quantity: qty ?? 1,
    );
  }

  VoiceCommand? _parseRemoveMulti(
    List<String> tokens,
    String text,
    VoiceLanguage language,
  ) {
    if (!_hasRemoveMark(text, language)) return null;
    final qty = _extractQuantity(tokens);
    final product = _extractProduct(tokens, _removeDropSet(language));
    if (product == null || product.isEmpty) return null;
    return RemoveProductCommand(
      productName: product,
      quantity: qty,
    );
  }

  VoiceCommand? _parseSetQuantityMulti(
    String text,
    VoiceLanguage language,
  ) {
    if (!_hasSetMark(text, language)) return null;
    final tokens = text.split(' ');
    final qty = _extractQuantity(tokens);
    if (qty == null) return null;
    final product = _extractProduct(tokens, _setDropSet(language));
    if (product == null || product.isEmpty) return null;
    return SetQuantityCommand(productName: product, quantity: qty);
  }

  VoiceCommand? _parsePriceMulti(String text, VoiceLanguage language) {
    final marks = switch (language) {
      VoiceLanguage.hindi => VoiceVocabulary.priceHindi,
      VoiceLanguage.marathi => VoiceVocabulary.priceMarathi,
      _ => VoiceVocabulary.priceHinglish,
    };
    if (!_matchesAnyToken(text, marks)) return null;
    final product = _extractProduct(
      text.split(' '),
      _priceDropSet(language),
    );
    if (product == null || product.isEmpty) return null;
    return PriceQueryCommand(productName: product);
  }

  VoiceCommand? _parseStockMulti(String text, VoiceLanguage language) {
    final marks = switch (language) {
      VoiceLanguage.hindi => VoiceVocabulary.stockHindi,
      VoiceLanguage.marathi => VoiceVocabulary.stockMarathi,
      _ => VoiceVocabulary.stockHinglish,
    };
    if (!_matchesAnyToken(text, marks)) return null;
    final product = _extractProduct(
      text.split(' '),
      _stockDropSet(language),
    );
    if (product == null || product.isEmpty) return null;
    return StockQueryCommand(productName: product);
  }

  bool _hasAddMark(String text, VoiceLanguage l) {
    final marks = switch (l) {
      VoiceLanguage.hindi => VoiceVocabulary.addHindi,
      VoiceLanguage.marathi => VoiceVocabulary.addMarathi,
      _ => VoiceVocabulary.addHinglish,
    };
    return _matchesAnyToken(text, marks);
  }

  bool _hasRemoveMark(String text, VoiceLanguage l) {
    final marks = switch (l) {
      VoiceLanguage.hindi => VoiceVocabulary.removeHindi,
      VoiceLanguage.marathi => VoiceVocabulary.removeMarathi,
      _ => VoiceVocabulary.removeHinglish,
    };
    return _matchesAnyToken(text, marks);
  }

  bool _hasSetMark(String text, VoiceLanguage l) {
    final marks = switch (l) {
      VoiceLanguage.hindi => VoiceVocabulary.setHindi,
      VoiceLanguage.marathi => VoiceVocabulary.setMarathi,
      _ => VoiceVocabulary.setHinglish,
    };
    return _matchesAnyToken(text, marks);
  }

  bool _matchesAnyToken(String text, List<String> marks) {
    for (final mark in marks) {
      if (_containsMarker(text, mark)) return true;
    }
    return false;
  }

  /// True when [mark] appears as a whole word/phrase in [text], so product
  /// names containing a command word don't accidentally trigger an intent.
  bool _containsMarker(String text, String mark) {
    return RegExp('\\b${RegExp.escape(mark)}\\b').hasMatch(text);
  }

  /// Extracts the first confidently-parsed quantity (1–20 any language,
  /// or digits). Ambiguous/multiple quantities return null.
  int? _extractQuantity(List<String> tokens) {
    int? found;
    for (final token in tokens) {
      final q = tryParseQuantityAnyLanguage(token);
      if (q != null) {
        if (found != null) return null; // ambiguous: more than one number
        found = q;
      }
    }
    return found;
  }

  /// Builds the product query by dropping known function/command words and
  /// quantity words, preserving order. Returns null (unknown) when nothing
  /// meaningful remains or a second quantity implies a compound number we
  /// can't confidently parse.
  String? _extractProduct(List<String> tokens, Set<String> drop) {
    final kept = <String>[];
    var quantities = 0;
    for (final token in tokens) {
      final isQty = tryParseQuantityAnyLanguage(token) != null;
      if (isQty) {
        quantities++;
        continue;
      }
      // Strip attached genitive/postposition suffixes first ("पेप्सीची"
      // -> "पेप्सी", "स्टॉकमध्ये" -> "स्टॉक") so intent words and product
      // names resolve exactly.
      final cleanedToken = _stripAttachedSuffix(token);
      if (drop.contains(cleanedToken)) continue;
      if (_isFunctionWord(cleanedToken)) continue;
      kept.add(cleanedToken);
    }
    if (quantities > 1) return null;
    final trimmed = kept.join(' ').trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  static final List<({String suffix, String strip})> _attachedSuffixes = [
    // Marathi genitive / postpositions (Devanagari).
    (suffix: 'ची', strip: 'ची'),
    (suffix: 'च्या', strip: 'च्या'),
    (suffix: 'चे', strip: 'चे'),
    (suffix: 'चा', strip: 'चा'),
    (suffix: 'ला', strip: 'ला'),
    (suffix: 'मध्ये', strip: 'मध्ये'),
    (suffix: 'साठी', strip: 'साठी'),
    // Hindi postpositions (Devanagari), usually separate words but STT may
    // glue them (e.g. "पेप्सीकी").
    (suffix: 'की', strip: 'की'),
    (suffix: 'के', strip: 'के'),
    (suffix: 'का', strip: 'का'),
    (suffix: 'को', strip: 'को'),
  ];

  /// Strips one trailing attached suffix; returns the token unchanged when
  /// nothing matches or stripping would empty it.
  String _stripAttachedSuffix(String token) {
    for (final entry in _attachedSuffixes) {
      if (token.endsWith(entry.suffix)) {
        final stripped = token.substring(0, token.length - entry.strip.length);
        if (stripped.isNotEmpty) return stripped;
        return token;
      }
    }
    return token;
  }

  static final Set<String> _functionWords = {
    // Roman / Hinglish.
    'ko', 'ke', 'ki', 'ka', 'kya', 'kyaa', 'hai', 'hain', 'mein', 'me', 'karo',
    'kitne', 'kitna', 'kitni', 'kitan', 'kitte', 'apne', 'se', 'aur', 'to',
    'the', 'a', 'an',
    // Hindi (Devanagari).
    'की', 'के', 'का', 'को', 'क्या', 'है', 'हैं', 'में', 'से', 'करो', 'कर',
    'कितने', 'कितनी', 'कितना', 'उपलब्ध',
    // Marathi (Devanagari).
    'ची', 'चा', 'चे', 'च्या', 'आहे', 'आहेत', 'करा', 'किती', 'शिल्लक',
  };

  bool _isFunctionWord(String token) => _functionWords.contains(token);

  Set<String> _addDropSet(VoiceLanguage l) =>
      {..._commonAdd, ...switch (l) {
        VoiceLanguage.hindi => VoiceVocabulary.addHindi,
        VoiceLanguage.marathi => VoiceVocabulary.addMarathi,
        _ => VoiceVocabulary.addHinglish,
      }};

  Set<String> _removeDropSet(VoiceLanguage l) =>
      {..._commonRemove, ...switch (l) {
        VoiceLanguage.hindi => VoiceVocabulary.removeHindi.toSet(),
        VoiceLanguage.marathi => VoiceVocabulary.removeMarathi.toSet(),
        _ => VoiceVocabulary.removeHinglish.toSet(),
      }};

  Set<String> _setDropSet(VoiceLanguage l) =>
      {for (final m in _commonSet) m, ...switch (l) {
        VoiceLanguage.hindi => VoiceVocabulary.setHindi.toSet(),
        VoiceLanguage.marathi => VoiceVocabulary.setMarathi.toSet(),
        _ => VoiceVocabulary.setHinglish.toSet(),
      }};

  Set<String> _priceDropSet(VoiceLanguage l) =>
      {..._commonPrice, ...switch (l) {
        VoiceLanguage.hindi => VoiceVocabulary.priceHindi.toSet(),
        VoiceLanguage.marathi => VoiceVocabulary.priceMarathi.toSet(),
        _ => VoiceVocabulary.priceHinglish.toSet(),
      }};

  Set<String> _stockDropSet(VoiceLanguage l) =>
      {..._commonStock, ...switch (l) {
        VoiceLanguage.hindi => VoiceVocabulary.stockHindi.toSet(),
        VoiceLanguage.marathi => VoiceVocabulary.stockMarathi.toSet(),
        _ => VoiceVocabulary.stockHinglish.toSet(),
      }};

  static const Set<String> _commonAdd = {'add'};
  static const Set<String> _commonRemove = {'remove'};
  static const Set<String> _commonSet = {'quantity', 'qty'};
  static const Set<String> _commonPrice = {'price', 'rate', 'daam'};
  static const Set<String> _commonStock = {'stock'};

  // ---------------------------------------------------------------------
  // Normalization & helpers
  // ---------------------------------------------------------------------

  String _normalize(String input) {
    var text = input.toLowerCase().trim();
    text = text.replaceAll(RegExp(r'[-_]'), ' ');
    // Strip common punctuation but keep Devanagari letters intact.
    text = text.replaceAll(RegExp(r'''[?.,!'"():;]'''), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = text.replaceAll(RegExp(r'^please\s+'), '');
    text = text.replaceAll(RegExp(r'\s+please$'), '');
    return text;
  }

  /// Strips a trailing "to cart" so "add pepsi to cart" resolves to "pepsi".
  static String _stripToCart(String name) {
    return name.replaceAll(RegExp(r'\s+to\s+(the\s+|my\s+)?cart$'), '').trim();
  }

  /// "pepsi are" → "pepsi" for "how many pepsi are in stock".
  static String _stripAux(String name) {
    return name.trim().replaceAll(RegExp(r'\s+(are|is)$'), '').trim();
  }
}
