import 'package:dofus_organizer/src/models/dofus_class.dart';
import 'package:dofus_organizer/src/ui/widgets/class_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Holds what the picker produced, filled once the dialog is closed.
class _Outcome {
  bool closed = false;
  ClassPickerResult? result;
}

void main() {
  Future<_Outcome> openPicker(WidgetTester tester, {String? initial}) async {
    final outcome = _Outcome();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                outcome.result =
                    await ClassPickerDialog.show(context, initial: initial);
                outcome.closed = true;
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    return outcome;
  }

  testWidgets('every class is offered', (tester) async {
    await openPicker(tester);
    for (final entry in kDofusClasses) {
      expect(find.text(entry.name), findsOneWidget);
    }
  });

  testWidgets('picking a class returns its masculine icon key',
      (tester) async {
    final outcome = await openPicker(tester);
    await tester.tap(find.text('Iop'));
    await tester.pumpAndSettle();

    expect(outcome.closed, isTrue);
    expect(outcome.result?.iconKey, 'iop_m');
  });

  testWidgets('the gender toggle switches the icon key', (tester) async {
    final outcome = await openPicker(tester);
    await tester.tap(find.text('Féminin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iop'));
    await tester.pumpAndSettle();

    expect(outcome.result?.iconKey, 'iop_f');
  });

  testWidgets('clearing returns no portrait', (tester) async {
    final outcome = await openPicker(tester, initial: 'iop_m');
    await tester.tap(find.text('Aucune'));
    await tester.pumpAndSettle();

    expect(outcome.closed, isTrue);
    expect(outcome.result, isNotNull);
    expect(outcome.result?.iconKey, isNull);
  });

  testWidgets('cancelling leaves the portrait untouched', (tester) async {
    final outcome = await openPicker(tester, initial: 'iop_m');
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(outcome.closed, isTrue);
    expect(outcome.result, isNull);
  });

  test('unknown icon keys resolve to null instead of a missing asset', () {
    expect(classIconAsset(null), isNull);
    expect(classIconAsset(''), isNull);
    expect(classIconAsset('iop'), isNull);
    expect(classIconAsset('iop_x'), isNull);
    expect(classIconAsset('inconnu_m'), isNull);
    expect(classIconAsset('iop_m'), 'assets/classes/iop_m.png');
    expect(classNameForIcon('cra_f'), 'Crâ');
  });
}
