/// Structured voice commands. Pure Dart — the deterministic parser produces
/// these, and the voice controller executes them. No LLM, no guessing.
///
/// Product names here are UNRESOLVED spoken text ("pepsi"); resolution
/// against active products happens afterward in the product matcher.
sealed class VoiceCommand {
  const VoiceCommand();
}

/// "Add 2 Pepsi" — merges into the existing cart line if present.
class AddProductCommand extends VoiceCommand {
  const AddProductCommand({required this.productName, required this.quantity});

  final String productName;
  final int quantity;
}

/// "Remove Pepsi" (whole line) or "Remove 2 Pepsi" (reduce by quantity,
/// removing the line when it reaches zero).
class RemoveProductCommand extends VoiceCommand {
  const RemoveProductCommand({required this.productName, this.quantity});

  final String productName;

  /// Null means the whole line.
  final int? quantity;
}

/// "Increase Pepsi" / "Increase Pepsi by 2".
class IncreaseProductCommand extends VoiceCommand {
  const IncreaseProductCommand({required this.productName, required this.quantity});

  final String productName;
  final int quantity;
}

/// "Decrease Pepsi" / "Decrease Pepsi by 1".
class DecreaseProductCommand extends VoiceCommand {
  const DecreaseProductCommand({required this.productName, required this.quantity});

  final String productName;
  final int quantity;
}

/// "Make Pepsi quantity five" / "Set Pepsi quantity to 5".
class SetQuantityCommand extends VoiceCommand {
  const SetQuantityCommand({required this.productName, required this.quantity});

  final String productName;
  final int quantity;
}

/// "Clear cart" — always confirmed before executing.
class ClearCartCommand extends VoiceCommand {
  const ClearCartCommand();
}

/// "What's the price of Pepsi?" — read-only, never touches the cart.
class PriceQueryCommand extends VoiceCommand {
  const PriceQueryCommand({required this.productName});

  final String productName;
}

/// "How many Pepsi are in stock?" — read-only, never touches inventory.
class StockQueryCommand extends VoiceCommand {
  const StockQueryCommand({required this.productName});

  final String productName;
}

/// "Checkout" — navigates to the checkout placeholder; no payment logic.
class CheckoutCommand extends VoiceCommand {
  const CheckoutCommand();
}

/// Anything the parser cannot confidently map. NEVER mutates the cart.
class UnknownCommand extends VoiceCommand {
  const UnknownCommand(this.transcript);

  final String transcript;
}
