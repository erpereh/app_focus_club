import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const kViewportSe = Size(320, 568);
const kViewportCompact = Size(360, 640);
const kViewportIphone14 = Size(390, 844);
const kViewportProMax = Size(430, 932);

void setLogicalViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void expectNoLayoutException(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

void expectSingleLineText(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  expect(text.maxLines, 1);
  expect(text.softWrap, isFalse);

  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final fontSize = paragraph.text.style?.fontSize ?? 18;
  final textScaler = MediaQuery.textScalerOf(tester.element(finder));
  final maxOneLineHeight = textScaler.scale(fontSize) * 1.75 + 4;
  expect(
    paragraph.size.height,
    lessThanOrEqualTo(maxOneLineHeight),
    reason: 'Expected "$text" to stay on a single line',
  );
}

class TextScaleHarness extends StatelessWidget {
  const TextScaleHarness({
    required this.child,
    this.textScaler = TextScaler.noScaling,
    super.key,
  });

  final Widget child;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child,
    );
  }
}
