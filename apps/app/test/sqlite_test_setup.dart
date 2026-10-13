import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';

/// Points the sqlite3 package at a real library on devbox/Nix hosts,
/// where libsqlite3.so lives in a nix store output instead of a system
/// directory. The shipped app never needs this: sqlite3_flutter_libs
/// bundles its own copy.
void overrideSqliteForTests() {
  open.overrideFor(OperatingSystem.linux, () {
    final envPaths = Platform.environment['LD_LIBRARY_PATH']?.split(':') ?? [];
    final candidates = [
      for (final dir in envPaths) '$dir/libsqlite3.so',
      '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
      '/usr/lib/x86_64-linux-gnu/libsqlite3.so',
      '/usr/lib/aarch64-linux-gnu/libsqlite3.so.0',
      for (final entry in Directory('/nix/store').listSync())
        if (entry.path.contains('sqlite-') &&
            entry is Directory &&
            File('${entry.path}/lib/libsqlite3.so').existsSync())
          '${entry.path}/lib/libsqlite3.so',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return DynamicLibrary.open(path);
    }
    return DynamicLibrary.open('libsqlite3.so');
  });
}
