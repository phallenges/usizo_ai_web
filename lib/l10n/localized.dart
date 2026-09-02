import 'package:flutter/material.dart';

import 'strings.dart';

/// Provides localized strings to the widget tree based on the current language.
///
/// Usage:
/// ```dart
/// Localized.of(context).t('checker.howAreYou')
/// ```
class Localized extends InheritedWidget {
  const Localized({
    required this.languageCode,
    required super.child,
    super.key,
  });

  final String languageCode;

  static Localized of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<Localized>();
    assert(result != null, 'No Localized found in context');
    return result!;
  }

  /// Translate a string key using the current language code.
  String t(String key) => s(key, lang: languageCode);

  @override
  bool updateShouldNotify(Localized oldWidget) =>
      languageCode != oldWidget.languageCode;
}

/// Convenience extension on BuildContext.
extension LocalizedContext on BuildContext {
  String tr(String key) => Localized.of(this).t(key);
}
