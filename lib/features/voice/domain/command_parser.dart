import 'voice_command.dart';

/// Deterministic, rule-based voice command parser. No LLM, no network.
///
/// Design bias: predictable FALSE NEGATIVES over dangerous false positives.
/// An utterance the parser cannot confidently map becomes [UnknownCommand],
/// which never mutates the cart.
///
/// Normalization: lowercase, hyphens→spaces, punctuation stripped,
/// whitespace collapsed, leading/trailing "please" removed.
/// Numbers: digits plus spoken words zero–twenty (and "a"/"an" = 1).
/// Anything more complex (e.g. "twenty two") is out of scope for V1 and
/// yields [UnknownCommand] rather than a guess.
class CommandParser {
  const CommandParser();

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

  VoiceCommand parse(String transcript) {
    final text = _normalize(transcript);
    if (text.isEmpty) return const UnknownCommand('');

    if (text == 'checkout' || text == 'check out') {
      return const CheckoutCommand();
    }
    if (RegExp(r'^(clear|empty)( the| my)? cart$').hasMatch(text)) {
      return const ClearCartCommand();
    }

    final add = _parseAdd(text);
    if (add != null) return add;
    final remove = _parseRemove(text);
    if (remove != null) return remove;
    final increase = _parseAdjust(text, 'increase');
    if (increase != null) return increase;
    final decrease = _parseAdjust(text, 'decrease');
    if (decrease != null) return decrease;
    final setQty = _parseSetQuantity(text);
    if (setQty != null) return setQty;

    final price = _parsePrice(text);
    if (price != null) return price;
    final stock = _parseStock(text);
    if (stock != null) return stock;

    return UnknownCommand(transcript.trim());
  }

  String _normalize(String input) {
    var text = input.toLowerCase();
    text = text.replaceAll(RegExp(r'[-_]'), ' ');
    text = text.replaceAll(RegExp(r'''[?.,!'"():;]'''), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = text.replaceAll(RegExp(r'^please\s+'), '');
    text = text.replaceAll(RegExp(r'\s+please$'), '');
    return text;
  }

  /// Strips a trailing "to cart" so "add pepsi to cart" resolves to "pepsi".
  String _stripToCart(String name) {
    return name.replaceAll(RegExp(r'\s+to\s+(the\s+|my\s+)?cart$'), '').trim();
  }

  VoiceCommand? _parseAdd(String text) {
    final match = RegExp(r'^add\s+(.+)$').firstMatch(text);
    if (match == null) return null;
    final rest = match.group(1)!.trim();
    final tokens = rest.split(' ');
    final qty = tryParseQuantity(tokens.first);
    if (qty != null) {
      if (tokens.length < 2) return UnknownCommand(text);
      // A second number word ("twenty two") is a compound quantity V1
      // cannot confidently parse — unknown rather than a guess.
      if (tryParseQuantity(tokens[1]) != null) return UnknownCommand(text);
      final name = _stripToCart(tokens.sublist(1).join(' '));
      if (name.isEmpty) return UnknownCommand(text);
      return AddProductCommand(productName: name, quantity: qty);
    }
    final name = _stripToCart(rest);
    if (name.isEmpty) return UnknownCommand(text);
    return AddProductCommand(productName: name, quantity: 1);
  }

  VoiceCommand? _parseRemove(String text) {
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

  VoiceCommand? _parseAdjust(String text, String verb) {
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

  VoiceCommand? _parseSetQuantity(String text) {
    final match =
        RegExp(r'^(make|set|change)\s+(.+?)\s+(?:quantity|qty)\s+(?:to\s+|is\s+)?(.+)$')
            .firstMatch(text);
    if (match == null) return null;
    final name = match.group(2)!.trim();
    final qty = tryParseQuantity(match.group(3)!.trim());
    if (name.isEmpty || qty == null) return UnknownCommand(text);
    return SetQuantityCommand(productName: name, quantity: qty);
  }

  VoiceCommand? _parsePrice(String text) {
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

  VoiceCommand? _parseStock(String text) {
    final howMany =
        RegExp(r'^how many (.+?) in stock$').firstMatch(text);
    if (howMany != null) {
      final name = _stripAux(howMany.group(1)!);
      if (name.isEmpty) return UnknownCommand(text);
      return StockQueryCommand(productName: name);
    }
    final howMuch =
        RegExp(r'^how much (.+?) (is |are )?left$').firstMatch(text);
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

  /// "pepsi are" → "pepsi" for "how many pepsi are in stock".
  String _stripAux(String name) {
    return name.trim().replaceAll(RegExp(r'\s+(are|is)$'), '').trim();
  }
}
