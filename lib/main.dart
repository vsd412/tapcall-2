import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'calling.dart';
import 'contacts.dart';
import 'home.dart';

void main() => runApp(TapCall(book: ContactBook(), provider: WhatsApp()));

class TapCall extends StatelessWidget {
  const TapCall({super.key, required this.book, required this.provider});
  final ContactBook book;
  final CallProvider provider;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TapCall 2',
    debugShowCheckedModeBanner: false,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [
      Locale('en'),
      Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'HK',
      ),
      Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      ),
      Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
        countryCode: 'CN',
      ),
    ],
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff125b54)),
      scaffoldBackgroundColor: const Color(0xfffaf9f5),
      useMaterial3: true,
    ),
    home: Home(book: book, provider: provider),
  );
}
