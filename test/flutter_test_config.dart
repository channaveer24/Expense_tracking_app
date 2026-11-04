import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the real Roboto + Material Icons fonts that ship with the Flutter
/// SDK, so layout tests measure text like a phone does (the default test
/// font draws every glyph as a wide square).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dir = Directory('$root/bin/cache/artifacts/material_fonts');
    if (dir.existsSync()) {
      Future<void> load(String family, List<String> files) async {
        final loader = FontLoader(family);
        for (final f in files) {
          final file = File('${dir.path}/$f');
          if (file.existsSync()) {
            loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
          }
        }
        await loader.load();
      }

      await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
      await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
    }
  }
  await testMain();
}
