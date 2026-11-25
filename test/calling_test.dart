import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapcall_two/calling.dart';
import 'package:tapcall_two/contacts.dart';
import 'package:tapcall_two/main.dart';

class TestCalls implements CallProvider {
  final videoRequests = <String>[];
  final chats = <String>[];
  CallOutcome outcome = CallOutcome.manual;
  Completer<CallOutcome>? pending;
  @override
  Future<CallOutcome> video(String number) async {
    videoRequests.add(number);
    return pending?.future ?? Future.value(outcome);
  }

  @override
  Future<CallOutcome> chat(String number) async {
    chats.add(number);
    return CallOutcome.opened;
  }

  @override
  Future<bool> allowLookup() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('local and international contacts retain the intended number', () {
    expect(Person.parseNumber('2345 6789'), '85223456789');
    expect(Person.parseNumber('+44 (20) 7123-4567'), '442071234567');
    expect(Person.parseNumber('0044 20 71234567'), '442071234567');
    expect(Person.parseNumber('12abc'), isNull);
    expect(Person.parseNumber('++85223'), isNull);
  });

  Future<TestCalls> start(WidgetTester t, {bool empty = false}) async {
    SharedPreferences.setMockInitialValues({});
    final book = ContactBook();
    if (!empty) await book.write([const Person('Family', '85223456789')]);
    final calls = TestCalls();
    await t.pumpWidget(TapCall(book: book, provider: calls));
    await t.pumpAndSettle();
    return calls;
  }

  testWidgets('adding a person persists name and international number', (
    t,
  ) async {
    await start(t, empty: true);
    await t.tap(find.text('Add a person'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Family');
    await t.enterText(find.byType(TextField).last, '2345 6789');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(find.text('Family'), findsOneWidget);
    expect((await ContactBook().read()).single.number, '85223456789');
  });

  testWidgets(
    'two quick taps request one call and chat needs an explicit tap',
    (t) async {
      final calls = await start(t);
      calls.pending = Completer();
      await t.tap(find.text('Family'));
      await t.tap(find.text('Family'));
      await t.pump();
      expect(calls.videoRequests, ['85223456789']);
      calls.pending!.complete(CallOutcome.manual);
      await t.pumpAndSettle();
      expect(calls.chats, isEmpty);
      await t.tap(find.text('Open chat'));
      await t.pumpAndSettle();
      expect(calls.chats, ['85223456789']);
    },
  );

  testWidgets('declining contact access still offers a chat', (t) async {
    final calls = await start(t);
    calls.outcome = CallOutcome.permission;
    await t.tap(find.text('Family'));
    await t.pumpAndSettle();
    await t.tap(find.text('Allow contact lookup'));
    await t.pumpAndSettle();
    expect(find.text('Open chat'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(calls.chats, isEmpty);
  });
  testWidgets(
    'caregiver edits persist and cancelling removal keeps the person',
    (t) async {
      await start(t);
      await t.tap(find.byTooltip('Manage contacts'));
      await t.pumpAndSettle();
      await t.tap(find.text('Family'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Anna');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect((await ContactBook().read()).single.name, 'Anna');
      await t.tap(find.byTooltip('Remove contact'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect((await ContactBook().read()).single.name, 'Anna');
      await t.tap(find.byTooltip('Remove contact'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Remove contact'));
      await t.pumpAndSettle();
      expect(await ContactBook().read(), isEmpty);
    },
  );
}
