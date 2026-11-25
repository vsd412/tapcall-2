import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapcall_two/board.dart';
import 'package:tapcall_two/calling.dart';
import 'package:tapcall_two/contacts.dart';
import 'package:tapcall_two/home.dart';

class FakeBoard extends TapBoard {
  late void Function(int) press;
  late void Function() loseConnection;

  @override
  Future<List<BluetoothDevice>> scan() async => [
    BluetoothDevice.fromId('test'),
  ];

  @override
  Future<void> connect(
    BluetoothDevice device,
    void Function(int) onButton,
    void Function() onLost,
  ) async {
    press = onButton;
    loseConnection = onLost;
  }
}

class RecordingCalls implements CallProvider {
  final numbers = <String>[];
  @override
  Future<CallOutcome> video(String number) async {
    numbers.add(number);
    return CallOutcome.opened;
  }

  @override
  Future<CallOutcome> chat(String number) => throw UnsupportedError('chat');
  @override
  Future<bool> allowLookup() => throw UnsupportedError('lookup');
}

void main() {
  test('only complete supported button presses trigger an action', () {
    for (final slot in [1, 2, 3, 254, 255]) {
      expect(boardButton('BTN:$slot\n'.codeUnits), slot);
    }
    for (final text in [
      'BTN:1',
      'REL:1\n',
      'VOL:50\n',
      'PIR:1\n',
      'BTN:253\n',
      'BTN:1\nBTN:2\n',
    ]) {
      expect(boardButton(text.codeUnits), isNull);
    }
  });

  testWidgets(
    'board keys follow the visible page and ignore unavailable slots and rapid taps',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final book = ContactBook();
      await book.write([
        for (var i = 1; i <= 4; i++) Person('Person $i', '8522345678$i'),
      ]);
      final board = FakeBoard();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final calls = RecordingCalls();
      await t.pumpWidget(
        MaterialApp(
          home: Home(book: book, provider: calls, board: board),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Manage contacts'));
      await t.pumpAndSettle();
      await t.tap(find.text('Connect TapCall board'));
      await t.pumpAndSettle();
      board.press(1);
      expect(calls.numbers, isEmpty);
      await t.tap(find.byTooltip('Close'));
      await t.pumpAndSettle();
      board.press(255);
      await t.pump();
      expect(find.text('Person 4'), findsOneWidget);
      expect(find.text('Person 1'), findsNothing);
      board.press(2);
      expect(calls.numbers, isEmpty);
      board.press(1);
      board.press(1);
      await t.pumpAndSettle();
      expect(calls.numbers, ['85223456784']);
      board.press(254);
      await t.pump();
      expect(find.text('Person 1'), findsOneWidget);
      board.loseConnection();
      await t.pump();
      board.press(2);
      expect(calls.numbers, hasLength(1));
    },
  );
}
