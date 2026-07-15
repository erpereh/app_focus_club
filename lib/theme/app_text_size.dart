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

  static Widget applyGlobally(BuildContext context, {required Widget child}) {
    if (!isLarge(context)) return child;
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: _MultipliedTextScaler(mediaQuery.textScaler, largeFactor),
      ),
      child: child,
    );
  }

  static double slotExtent(BuildContext context) => isLarge(context) ? 100 : 88;

  static double dateExtent(BuildContext context) => isLarge(context) ? 88 : 78;

  static double navigationItemMinHeight(BuildContext context) =>
      isLarge(context) ? 60 : 52;
}

@immutable
final class _MultipliedTextScaler implements TextScaler {
  const _MultipliedTextScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  double get textScaleFactor => base.scale(1) * factor;

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) {
    if (minScaleFactor == 0 && maxScaleFactor == double.infinity) return this;
    if (minScaleFactor == maxScaleFactor) {
      return TextScaler.linear(minScaleFactor);
    }
    return _ClampedAppTextScaler(this, minScaleFactor, maxScaleFactor);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MultipliedTextScaler &&
          other.base == base &&
          other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}

@immutable
final class _ClampedAppTextScaler implements TextScaler {
  const _ClampedAppTextScaler(this.base, this.minScale, this.maxScale);

  final TextScaler base;
  final double minScale;
  final double maxScale;

  @override
  double scale(double fontSize) => base
      .scale(fontSize)
      .clamp(minScale * fontSize, maxScale * fontSize)
      .toDouble();

  @override
  double get textScaleFactor =>
      base.scale(1).clamp(minScale, maxScale).toDouble();

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) {
    final nextMin = minScaleFactor > minScale ? minScaleFactor : minScale;
    final nextMax = maxScaleFactor < maxScale ? maxScaleFactor : maxScale;
    if (nextMin == nextMax) return TextScaler.linear(nextMin);
    return _ClampedAppTextScaler(base, nextMin, nextMax);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ClampedAppTextScaler &&
          other.base == base &&
          other.minScale == minScale &&
          other.maxScale == maxScale;

  @override
  int get hashCode => Object.hash(base, minScale, maxScale);
}
