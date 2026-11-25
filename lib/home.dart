import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' show BluetoothDevice;

import 'board.dart';
import 'calling.dart';
import 'contact_tile.dart';
import 'contacts.dart';
import 'editor.dart';
import 'words.dart';

class Home extends StatefulWidget {
  const Home({
    super.key,
    required this.book,
    required this.provider,
    this.board,
  });
  final TapBoard? board;
  final ContactBook book;
  final CallProvider provider;
  @override
  State<Home> createState() => _HomeState();
}

enum _Choice { lookup, chat }

class _HomeState extends State<Home> {
  List<Person>? people;
  bool managing = false, working = false, loadFailed = false;
  static const colors = [
    Color(0xff16584f),
    Color(0xff244d73),
    Color(0xff72482f),
  ];

  @override
  void initState() {
    super.initState();
    load();
  }

  late final board = widget.board ?? TapBoard();
  bool connected = false;
  int page = 0;

  @override
  void dispose() {
    board.close();
    super.dispose();
  }

  Future<void> configureBoard() async {
    final w = Words(context);
    setState(() => working = true);
    try {
      if (connected) {
        await board.close();
        if (mounted) {
          setState(() {
            connected = false;
            page = 0;
          });
        }
        return;
      }
      final devices = await board.scan();
      if (!mounted) return;
      if (devices.isEmpty) {
        message(w.noBoard);
        return;
      }
      final device = devices.length == 1
          ? devices.first
          : await showDialog<BluetoothDevice>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: Text(w.connectBoard),
                children: [
                  for (final d in devices)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, d),
                      child: Text(d.remoteId.str),
                    ),
                ],
              ),
            );
      if (device == null || !mounted) return;
      await board.connect(device, handleButton, () {
        if (!mounted) return;
        setState(() {
          connected = false;
          page = 0;
        });
        message(w.boardLost);
      });
      if (!mounted) {
        await board.close();
        return;
      }
      setState(() => connected = true);
    } catch (_) {
      if (mounted) message(w.boardError);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  void handleButton(int slot) {
    if (!mounted ||
        !connected ||
        managing ||
        working ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final count = people?.length ?? 0;
    if (slot == 254 || slot == 255) {
      final last = count == 0 ? 0 : (count - 1) ~/ 3;
      setState(() => page = (page + (slot == 254 ? -1 : 1)).clamp(0, last));
    } else {
      final index = page * 3 + slot - 1;
      if (index >= 0 && index < count) call(people![index]);
    }
  }

  Future<void> load() async {
    try {
      final rows = await widget.book.read();
      if (mounted) {
        setState(() {
          people = rows;
          loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loadFailed = true);
    }
  }

  void message(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> update(List<Person> next) async {
    setState(() => working = true);
    try {
      await widget.book.write(next);
      if (mounted) {
        setState(() {
          people = next;
          page = 0;
        });
      }
    } catch (_) {
      if (mounted) message(Words(context).error);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> edit([int? index]) async {
    final value = await Navigator.of(context).push<Person>(
      MaterialPageRoute(
        builder: (_) =>
            ContactEditor(person: index == null ? null : people![index]),
      ),
    );
    if (value == null || !mounted) return;
    final next = [...people!];
    if (index == null) {
      next.add(value);
    } else {
      next[index] = value;
    }
    await update(next);
  }

  Future<void> remove(int index) async {
    final w = Words(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(w.remove),
        content: Text(people![index].name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(w.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(w.remove),
          ),
        ],
      ),
    );
    if (mounted && yes == true) await update([...people!]..removeAt(index));
  }

  Future<_Choice?> options(Person person, Words w, bool permission) =>
      showDialog<_Choice>(
        context: context,
        builder: (ctx) => AlertDialog(
          scrollable: true,
          title: Text(person.name),
          content: Text(permission ? w.permission : w.manual),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(w.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _Choice.chat),
              child: Text(w.openChat),
            ),
            if (permission)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, _Choice.lookup),
                child: Text(w.enable),
              ),
          ],
        ),
      );

  final launchClock = Stopwatch()..start();
  int? acceptedAt;

  Future<void> call(Person person) async {
    final last = acceptedAt;
    if (working ||
        (last != null && launchClock.elapsedMilliseconds - last < 700)) {
      return;
    }
    setState(() => working = true);
    final w = Words(context);
    try {
      var outcome = await widget.provider.video(person.number);
      while (mounted &&
          (outcome == CallOutcome.manual ||
              outcome == CallOutcome.permission)) {
        final choice = await options(
          person,
          w,
          outcome == CallOutcome.permission,
        );
        if (choice == null || !mounted) return;
        if (choice == _Choice.chat) {
          outcome = await widget.provider.chat(person.number);
        } else {
          final allowed = await widget.provider.allowLookup();
          if (!mounted) return;
          outcome = allowed
              ? await widget.provider.video(person.number)
              : CallOutcome.manual;
        }
      }
      if (outcome == CallOutcome.opened) {
        acceptedAt = launchClock.elapsedMilliseconds;
      } else if (mounted && outcome != CallOutcome.ignored) {
        message(outcome == CallOutcome.missing ? w.missing : w.error);
      }
    } catch (_) {
      if (mounted) message(w.error);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = Words(context);
    final rows = people;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TapCall 2',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (rows != null)
            IconButton(
              tooltip: managing
                  ? MaterialLocalizations.of(context).closeButtonTooltip
                  : w.manage,
              onPressed: working
                  ? null
                  : () => setState(() => managing = !managing),
              icon: Icon(managing ? Icons.close : Icons.settings_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: rows == null
            ? Center(
                child: loadFailed
                    ? FilledButton(onPressed: load, child: Text(w.retry))
                    : const CircularProgressIndicator(),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      managing ? w.manage : w.people,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Text(
                        w.empty,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  if (managing || rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(58),
                        ),
                        onPressed: working ? null : () => edit(),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(
                          w.add,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  if (managing)
                    OutlinedButton.icon(
                      onPressed: working ? null : configureBoard,
                      icon: const Icon(Icons.bluetooth),
                      label: Text(
                        connected ? w.disconnectBoard : w.connectBoard,
                      ),
                    ),
                  if (connected && !managing && rows.length > 3)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).previousPageTooltip,
                          onPressed: page > 0 ? () => handleButton(254) : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('${page + 1} / ${(rows.length + 2) ~/ 3}'),
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).nextPageTooltip,
                          onPressed: (page + 1) * 3 < rows.length
                              ? () => handleButton(255)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  for (var i = 0; i < rows.length; i++)
                    if (managing || !connected || i ~/ 3 == page)
                      if (managing)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            rows[i].name,
                            style: const TextStyle(fontSize: 22),
                          ),
                          subtitle: Text('+${rows[i].number}'),
                          onTap: working ? null : () => edit(i),
                          trailing: IconButton(
                            tooltip: w.remove,
                            onPressed: working ? null : () => remove(i),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        )
                      else
                        ContactTile(
                          person: rows[i],
                          label: w.video,
                          color: colors[i % colors.length],
                          onTap: working ? null : () => call(rows[i]),
                        ),
                ],
              ),
      ),
    );
  }
}
