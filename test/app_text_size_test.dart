import 'package:app_focus_club/theme/app_text_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('large text scales only opted-in styles and component extents', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _TextSizeHarness()));

    expect(_fontSize(tester), 20);
    expect(
      tester.widget<SizedBox>(find.byKey(const Key('slot-extent'))).height,
      88,
    );
    expect(
      tester.widget<SizedBox>(find.byKey(const Key('date-extent'))).height,
      78,
    );

    await tester.tap(find.byKey(const Key('use-large-text')));
    await tester.pump();

    expect(_fontSize(tester), 23);
    expect(
      tester.widget<SizedBox>(find.byKey(const Key('slot-extent'))).height,
      100,
    );
    expect(
      tester.widget<SizedBox>(find.byKey(const Key('date-extent'))).height,
      88,
    );
  });
}

double? _fontSize(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const Key('important-text')))
      .style
      ?.fontSize;
}

class _TextSizeHarness extends StatefulWidget {
  const _TextSizeHarness();

  @override
  State<_TextSizeHarness> createState() => _TextSizeHarnessState();
}

class _TextSizeHarnessState extends State<_TextSizeHarness> {
  AppTextSize _textSize = AppTextSize.defaultSize;

  @override
  Widget build(BuildContext context) {
    return AppTextSizeScope(
      textSize: _textSize,
      onChanged: (value) => setState(() => _textSize = value),
      child: Builder(
        builder: (context) => Column(
          children: [
            Text(
              'Importante',
              key: const Key('important-text'),
              style: AppTextSizing.scaled(
                context,
                const TextStyle(fontSize: 20),
              ),
            ),
            SizedBox(
              key: const Key('slot-extent'),
              height: AppTextSizing.slotExtent(context),
            ),
            SizedBox(
              key: const Key('date-extent'),
              height: AppTextSizing.dateExtent(context),
            ),
            TextButton(
              key: const Key('use-large-text'),
              onPressed: () => AppTextSizeScope.set(context, AppTextSize.large),
              child: const Text('Grande'),
            ),
          ],
        ),
      ),
    );
  }
}
