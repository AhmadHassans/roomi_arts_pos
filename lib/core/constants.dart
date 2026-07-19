/// App-wide fixed values kept in one place so wording/sizes stay consistent.
///
/// Design rules (owner is NOT tech-savvy):
///  - Big buttons (>= 52px tall), large high-contrast text (16px+).
///  - Every button/icon ALWAYS has a text label. Never icon-only.
///  - Plain simple words. Same layout on every screen.
library;

class AppText {
  static const shopName = 'Roomi Arts';
  static const shopTagline = 'Stationery - Art - School';
  static const shopAddress = 'Pia Road, Lahore';
  static const shopPhone = 'Ph: 0333-4076476';
}

/// Shared sizes so muscle memory forms (same everywhere).
class Sizes {
  static const double buttonHeight = 56; // >= 52px requirement
  static const double bodyText = 16; // minimum readable size
  static const double titleText = 22;
  static const double bigText = 30;
  static const double radius = 14; // rounded cards
  static const double gap = 16; // generous spacing
  static const double sidebarWidth = 220;
}

/// The four product categories used by the quick buttons on the Sale screen.
class Categories {
  static const List<String> all = ['Pens', 'Copies', 'Art', 'School'];

  /// Soft category colour (used as a gentle tint, never loud).
  static const Map<String, int> colors = {
    'Pens': 0xFFEAF2FF, // soft blue
    'Copies': 0xFFFFF3E0, // soft amber
    'Art': 0xFFFCE8F3, // soft pink
    'School': 0xFFEAF7EA, // soft green
  };
}

/// Units. Stock is always counted in single pieces (see STOCK RULE).
class Units {
  static const List<String> all = ['piece', 'box'];
}

/// Rows with stock below this are highlighted (low stock).
const int kLowStockThreshold = 5;

/// A cashier may apply a discount up to this percentage of the bill. Anything
/// larger is a "big discount" and needs an owner to be logged in.
const double kCashierMaxDiscountPercent = 20;

/// Lock the screen automatically after this many minutes of no activity.
const int kAutoLockMinutes = 5;