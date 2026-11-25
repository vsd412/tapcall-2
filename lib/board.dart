import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// The firmware sends one ASCII line per GATT notification.
int? boardButton(List<int> bytes) {
  final match = RegExp(
    r'^BTN:(1|2|3|254|255)\n$',
  ).firstMatch(String.fromCharCodes(bytes));
  return match == null ? null : int.parse(match[1]!);
}

class TapBoard {
  static final serviceId = Guid('4fafc201-1fb5-459e-8fcc-c5c9c331914b');
  static final outputId = Guid('beb5483e-36e1-4688-b7f5-ea07361b26a8');

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _values;
  StreamSubscription<BluetoothConnectionState>? _state;

  Future<List<BluetoothDevice>> scan() async {
    await FlutterBluePlus.startScan(
      withServices: [serviceId],
      timeout: const Duration(seconds: 5),
    );
    await FlutterBluePlus.isScanning.where((active) => !active).first;
    return FlutterBluePlus.lastScanResults.map((r) => r.device).toList();
  }

  Future<void> connect(
    BluetoothDevice device,
    void Function(int) onButton,
    void Function() onLost,
  ) async {
    await close();
    _device = device;
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      final services = await device.discoverServices();
      final service = services.singleWhere((s) => s.uuid == serviceId);
      final output = service.characteristics.singleWhere(
        (c) => c.uuid == outputId,
      );
      _values = output.onValueReceived.listen((bytes) {
        final slot = boardButton(bytes);
        if (slot != null) onButton(slot);
      });
      await output.setNotifyValue(true);
      _state = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) onLost();
      });
    } catch (_) {
      await close();
      rethrow;
    }
  }

  Future<void> close() async {
    final device = _device;
    _device = null;
    await _state?.cancel();
    await _values?.cancel();
    await device?.disconnect();
  }
}
