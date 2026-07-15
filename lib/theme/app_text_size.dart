import 'package:flutter/material.dart';

enum AppTextSize { defaultSize, large }

class AppTextSizeScope extends InheritedWidget {
  const AppTextSizeScope({
    required this.textSize,
    required this.onChanged,
    required super.child,
    super.key,
  });

  final AppTextSize textSize;
  final ValueChanged<AppTextSize> onChanged;

  static AppTextSize of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AppTextSizeScope>()
            ?.textSize ??
        AppTextSize.defaultSize;
  }

  static void set(BuildContext context, AppTextSize value) {
    context.dependOnInheritedWidgetOfExactType<AppTextSizeScope>()?.onChanged(
      value,
    );
  }

  @override
  bool updateShouldNotify(AppTextSizeScope oldWidget) {
    return textSize != oldWidget.textSize || onChanged != oldWidget.onChanged;
  }
}

class AppTextSizing {
  const AppTextSizing._();

  static const double largeFactor = 1.15;

  static bool isLarge(BuildContext context) =>
      AppTextSizeScope.of(context) == AppTextSize.large;

  static TextStyle? scaled(BuildContext context, TextStyle? style) {
    if (!isLarge(context) || style?.fontSize == null) return style;
    return style!.copyWith(fontSize: style.fontSize! * largeFactor);
  }

  static Widget region(BuildContext context, {required Widget child}) {
    if (!isLarge(context)) return child;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontSizeFactor: largeFactor),
      ),
      child: child,
    );
  }

  static double slotExtent(BuildContext context) => isLarge(context) ? 100 : 88;

  static double dateExtent(BuildContext context) => isLarge(context) ? 88 : 78;
}
