import 'package:flutter/material.dart';

import 'calling.dart';
import 'contact_tile.dart';
import 'contacts.dart';
import 'editor.dart';
import 'words.dart';

class Home extends StatefulWidget {
  const Home({super.key, required this.book, required this.provider});
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
      if (mounted) setState(() => people = next);
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

  Future<void> call(Person person) async {
    if (working) return;
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
      if (mounted && outcome != CallOutcome.opened) {
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
                  for (var i = 0; i < rows.length; i++)
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
