import 'package:flutter/services.dart';

enum CallOutcome { opened, permission, manual, missing, unavailable }

/// Implement this contract for an additional calling app or platform.
abstract interface class CallProvider {
  Future<CallOutcome> video(String number);
  Future<CallOutcome> chat(String number);
  Future<bool> allowLookup();
}

class WhatsApp implements CallProvider {
  static const _channel = MethodChannel('tapcall/whatsapp');

  @override
  Future<CallOutcome> video(String number) => _open('video', number);
  @override
  Future<CallOutcome> chat(String number) => _open('chat', number);
  @override
  Future<bool> allowLookup() async =>
      await _channel.invokeMethod<bool>('allowLookup') ?? false;

  Future<CallOutcome> _open(String method, String number) async {
    final result = await _channel.invokeMethod<String>(method, number);
    return CallOutcome.values.firstWhere(
      (s) => s.name == result,
      orElse: () => CallOutcome.unavailable,
    );
  }
}
