import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'contacts.dart';
import 'words.dart';

class ContactEditor extends StatefulWidget {
  const ContactEditor({super.key, this.person});
  final Person? person;
  @override
  State<ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<ContactEditor> {
  late final name = TextEditingController(text: widget.person?.name);
  late final number = TextEditingController(
    text: widget.person == null ? '' : '+${widget.person!.number}',
  );
  late Uint8List? photo = widget.person?.photo;
  bool invalid = false;
  bool picking = false;

  Future<void> choosePhoto() async {
    setState(() => picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 192,
        maxHeight: 192,
        requestFullMetadata: false,
      );
      if (file == null) return;
      // Store only a small thumbnail. An editor cancellation discards it.
      final codec = await ui.instantiateImageCodec(
        await file.readAsBytes(),
        targetWidth: 96,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      try {
        final bytes = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (mounted && bytes != null) {
          setState(() => photo = bytes.buffer.asUint8List());
        }
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Words(context).error)));
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    number.dispose();
    super.dispose();
  }

  void save() {
    final digits = Person.parseNumber(number.text);
    if (name.text.trim().isEmpty || digits == null) {
      setState(() => invalid = true);
      return;
    }
    Navigator.pop(context, Person(name.text.trim(), digits, photo));
  }

  @override
  Widget build(BuildContext context) {
    final w = Words(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.person == null ? w.add : w.edit)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (photo != null)
                  ClipOval(
                    child: Image.memory(
                      photo!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: picking ? null : choosePhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(w.photo),
                ),
                if (photo != null)
                  IconButton(
                    tooltip: w.clearPhoto,
                    onPressed: () => setState(() => photo = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: w.name,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: number,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: w.phone,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(w.hint, style: const TextStyle(fontSize: 16)),
            if (invalid)
              Semantics(
                liveRegion: true,
                child: Text(
                  w.invalid,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: picking ? null : save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: Text(w.save, style: const TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
