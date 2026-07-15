import 'package:app_focus_club/theme/app_text_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('large text multiplies the system scaler globally', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.25)),
        child: MaterialApp(home: _TextSizeHarness()),
      ),
    );

    expect(_scaledFontSize(tester, const Key('themed-text')), 25);
    expect(_scaledFontSize(tester, const Key('explicit-text')), 25);
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

    expect(
      _scaledFontSize(tester, const Key('themed-text')),
      closeTo(28.75, 0.001),
    );
    expect(
      _scaledFontSize(tester, const Key('explicit-text')),
      closeTo(28.75, 0.001),
    );
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

double _scaledFontSize(WidgetTester tester, Key key) {
  final context = tester.element(find.byKey(key));
  return MediaQuery.textScalerOf(context).scale(20);
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
        builder: (context) => AppTextSizing.applyGlobally(
          context,
          child: Column(
            children: [
              Text(
                'Tema',
                key: const Key('themed-text'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Text(
                'Explícito',
                key: Key('explicit-text'),
                style: TextStyle(fontSize: 20),
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
                onPressed: () =>
                    AppTextSizeScope.set(context, AppTextSize.large),
                child: const Text('Grande'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
