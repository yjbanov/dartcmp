// Copyright 2018 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io' as io;

import 'package:meta/meta.dart';
import 'package:args/args.dart' as arg;
import 'package:path/path.dart' as path_lib;
import 'package:mustache/mustache.dart' as mustache;

import 'package:dartcmp/dartcmp.dart';
import 'package:dartcmp/template.dart';

/// Generates a report of differences between two Dart packages.
void main(List<String> rawArgs) {
  final argp = arg.ArgParser()
    ..addOption('a', help: 'path to the first Dart package')
    ..addOption('b', help: 'path to the second Dart package')
    ..addOption('o',
        help: 'path for the output file (existing file will be overwritten)')
    ..addMultiOption('i', help: 'paths to ignore');
  final args = argp.parse(rawArgs);

  final String outputPath = args['o'];
  final ignorePaths = args['i'];
  final aDir = io.Directory(args['a']);
  final bDir = io.Directory(args['b']);
  final aLibDir = io.Directory(path_lib.join(aDir.path, 'lib'));
  final bLibDir = io.Directory(path_lib.join(bDir.path, 'lib'));
  final aTestDir = io.Directory(path_lib.join(aDir.path, 'test'));
  final bTestDir = io.Directory(path_lib.join(bDir.path, 'test'));

  final libDelta = _DirectoryDelta.from(aLibDir, bLibDir, ignorePaths);
  final testDelta = _DirectoryDelta.from(aTestDir, bTestDir, ignorePaths);

  final output = mustache.Template(html, htmlEscapeValues: false).renderString({
    'date': DateTime.now().toString(),
    // File differences
    'files': _progress(
      libDelta.matchingFiles.length,
      libDelta.missingLibraries.length,
      libDelta.extraLibraries.length,
    ),
    'matchingFiles': libDelta.matchingFiles,
    'missingFiles': libDelta.missingFiles,
    'extraFiles': libDelta.extraFiles,

    // Class differences
    'classes': _progress(
      libDelta.matchingClasses.length,
      libDelta.missingClasses.length,
      libDelta.extraClasses.length + libDelta.misplacedClasses.length,
    ),
    'matchingClasses': libDelta.matchingClasses,
    'missingClasses': libDelta.missingClasses,
    'misplacedClasses': libDelta.misplacedClassesFormatted,
    'extraClasses': libDelta.extraClasses,

    // Test file differences
    'testFiles': _progress(
      testDelta.matchingFiles.length,
      testDelta.missingLibraries.length,
      testDelta.extraLibraries.length,
    ),
    'matchingTestFiles': testDelta.matchingFiles,
    'missingTestFiles': testDelta.missingFiles,
    'extraTestFiles': testDelta.extraFiles,
  });

  if (outputPath != null) {
    io.File(outputPath).writeAsStringSync(output);
  } else {
    print(output);
  }
}

class _DirectoryDelta {
  _DirectoryDelta({
    @required this.matchingFiles,
    @required this.missingFiles,
    @required this.extraFiles,
    @required this.missingLibraries,
    @required this.extraLibraries,
    @required this.libraryDeltas,
    @required this.matchingClasses,
    @required this.missingClasses,
    @required this.extraClasses,
    @required this.misplacedClasses,
    @required this.misplacedClassesFormatted,
  });

  final List<String> matchingFiles;
  final List<String> missingFiles;
  final List<String> extraFiles;

  final List<LibrarySummary> missingLibraries;
  final List<LibrarySummary> extraLibraries;
  final Map<String, LibraryDelta> libraryDeltas;

  final List<String> matchingClasses;
  final List<String> missingClasses;
  final List<String> extraClasses;
  final List<String> misplacedClasses;
  final List<String> misplacedClassesFormatted;

  static _DirectoryDelta from(io.Directory aDir, io.Directory bDir, List<String> ignorePaths) {
    final Map<String, LibrarySummary> aLibraries = _flattenAndParse(aDir, ignorePaths);
    final Map<String, LibrarySummary> bLibraries = _flattenAndParse(bDir, ignorePaths);

    final List<String> matchingFiles = <String>[];
    final List<LibrarySummary> missingLibraries = <LibrarySummary>[];
    final List<LibrarySummary> extraLibraries = <LibrarySummary>[];
    final Map<String, LibraryDelta> libraryDeltas = <String, LibraryDelta>{};

    bLibraries.forEach((String name, LibrarySummary bLib) {
      if (!aLibraries.containsKey(name)) {
        missingLibraries.add(bLib);
        return;
      }

      matchingFiles.add(name);
      final aLib = aLibraries[name];
      final libraryDelta = LibraryDelta.between(aLib, bLib);
      libraryDeltas[name] = libraryDelta;
    });

    aLibraries.forEach((String name, LibrarySummary aLib) {
      if (!bLibraries.containsKey(name)) {
        extraLibraries.add(aLib);
      }
    });

    final matchingClasses =
        libraryDeltas.values.expand((d) => d.classDelta.matching).toList();

    // Extra classes can come from matching libraries as well as from extra
    // libraries.
    final extraClasses =
        libraryDeltas.values.expand((d) => d.classDelta.extra).toList();
    extraClasses.addAll(
        extraLibraries.expand((lib) => lib.classes.map((c) => c.className)));

    // All missing classes, includes potentially misplaced ones.
    final strictlyMissingClasses = missingLibraries
        .expand((lib) => lib.classes.map((c) => c.className))
        .toList();
    strictlyMissingClasses
        .addAll(libraryDeltas.values.expand<String>((d) => d.classDelta.missing));

    // Break down all missing classes into truly missing and possibly misplaced.
    final missingClasses = <String>[];
    final misplacedClasses = <String>[];
    final misplacedClassesFormatted = <String>[];

    // Find missing and potentially misplaced classes.
    strictlyMissingClasses.forEach((String missingClass) {
      // See if a class with the same name exists elsewhere (i.e. potentially misplaced)
      final locations = <String>[];
      for (LibrarySummary library in aLibraries.values) {
        if (library.containsClass(missingClass)) {
          locations.add(library.relativePath);
        }
      }

      if (locations.isEmpty) {
        // Didn't find a class with the same name elsewhere. Must be truly missing.
        missingClasses.add(missingClass);
      } else {
        // Found a class with the same name. Possibly misplaced.
        misplacedClasses.add(missingClass);
        misplacedClassesFormatted.add(
            '${missingClass} <ul>${locations.map((l) => '<li>$l</li>').join('')}</ul>');
      }
    });

    // Remove misplaced classes from the list of extra classes.
    misplacedClasses.forEach(extraClasses.remove);

    final missingFiles = missingLibraries.map((l) => l.relativePath).toList();
    final extraFiles = extraLibraries.map((l) => l.relativePath).toList();

    return _DirectoryDelta(
      matchingFiles: matchingFiles,
      missingFiles: missingFiles,
      extraFiles: extraFiles,
      missingLibraries: missingLibraries,
      extraLibraries: extraLibraries,
      libraryDeltas: libraryDeltas,
      matchingClasses: matchingClasses,
      missingClasses: missingClasses,
      extraClasses: extraClasses,
      misplacedClasses: misplacedClasses,
      misplacedClassesFormatted: misplacedClassesFormatted,
    );
  }
}

Map<String, dynamic> _progress(num done, num todo, num doneish) {
  final double total = (done + doneish + todo).toDouble();
  return <String, dynamic>{
    'done': (100.0 * done / total).toStringAsFixed(2),
    'doneish': (100.0 * doneish / total).toStringAsFixed(2),
    'todo': (100.0 * todo / total).toStringAsFixed(2),
  };
}

Map<String, LibrarySummary> _flattenAndParse(
    io.Directory directory, List<String> ignoreList) {
  final List<io.File> files = directory
      .listSync(recursive: true)
      .whereType<io.File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final result = <String, LibrarySummary>{};
  for (final file in files) {
    final relativePath = path_lib.relative(file.path, from: directory.path);
    if (ignoreList.any(relativePath.startsWith)) {
      // Ignore.
      continue;
    }
    result[relativePath] = LibrarySummary.parse(file, relativePath: relativePath);
  }
  return result;
}
