import 'dart:io' as io;

import 'package:meta/meta.dart';
import 'package:analyzer/analyzer.dart';
import 'package:args/args.dart' as arg;
import 'package:path/path.dart' as path_lib;
import 'package:mustache/mustache.dart' as mustache;

import 'template.dart';

void main(List<String> rawArgs) {
  final argp = arg.ArgParser()
    ..addOption('a', help: 'path to the first Dart package')
    ..addOption('b', help: 'path to the second Dart package')
    ..addOption('o',
        help: 'path for the output file (existing file will be overwritten)')
    ..addMultiOption('i', help: 'paths to ignore');
  final args = argp.parse(rawArgs);

  final String outputPath = args['o'];
  final aDir = io.Directory(args['a']);
  final bDir = io.Directory(args['b']);
  final ignorePaths = args['i'];
  final Map<String, _LibrarySummary> aLibraries = _flattenAndParse(aDir, ignorePaths);
  final Map<String, _LibrarySummary> bLibraries = _flattenAndParse(bDir, ignorePaths);

  final List<String> matchingFiles = <String>[];
  final List<_LibrarySummary> missingLibraries = <_LibrarySummary>[];
  final List<_LibrarySummary> extraLibraries = <_LibrarySummary>[];
  final Map<String, _LibraryDelta> libraryDeltas = <String, _LibraryDelta>{};

  bLibraries.forEach((String name, _LibrarySummary bLib) {
    if (!aLibraries.containsKey(name)) {
      missingLibraries.add(bLib);
      return;
    }

    matchingFiles.add(name);
    final aLib = aLibraries[name];
    final libraryDelta = aLib.deltaFrom(bLib);
    libraryDeltas[name] = libraryDelta;
  });

  aLibraries.forEach((String name, _LibrarySummary aLib) {
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
    for (_LibrarySummary library in aLibraries.values) {
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

  final output = mustache.Template(html, htmlEscapeValues: false).renderString({
    'date': DateTime.now().toString(),
    // File differences
    'files': _progress(
      matchingFiles.length,
      missingLibraries.length,
      extraLibraries.length,
    ),
    'matchingFiles': matchingFiles,
    'missingFiles': missingFiles,
    'extraFiles': extraFiles,

    // Class differences
    'classes': _progress(
      matchingClasses.length,
      missingClasses.length,
      extraClasses.length + misplacedClasses.length,
    ),
    'matchingClasses': matchingClasses,
    'missingClasses': missingClasses,
    'misplacedClasses': misplacedClassesFormatted,
    'extraClasses': extraClasses,
  });

  if (outputPath != null) {
    io.File(outputPath).writeAsStringSync(output);
  } else {
    print(output);
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

class _StringListDiff {
  _StringListDiff(this.missing, this.extra, this.matching);

  final List<String> missing;
  final List<String> extra;
  final List<String> matching;

  bool get isDifferent => missing.isNotEmpty || extra.isNotEmpty;
}

_StringListDiff _diffStringLists(List<String> a, List<String> b) {
  final missing = <String>[];
  final extra = <String>[];
  final matching = <String>[];

  for (var string in b) {
    if (!a.contains(string)) {
      missing.add(string);
    } else {
      matching.add(string);
    }
  }
  for (var string in a) {
    if (!b.contains(string)) {
      extra.add(string);
    }
  }

  return _StringListDiff(missing, extra, matching);
}

Map<String, _LibrarySummary> _flattenAndParse(
    io.Directory directory, List<String> ignoreList) {
  final List<io.File> files = directory
      .listSync(recursive: true)
      .whereType<io.File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final result = <String, _LibrarySummary>{};
  for (final file in files) {
    final relativePath = path_lib.relative(file.path, from: directory.path);
    if (ignoreList.any(relativePath.startsWith)) {
      // Ignore.
      continue;
    }
    result[relativePath] = _parse(file, relativePath);
  }
  return result;
}

_LibrarySummary _parse(io.File file, String relativePath) {
  final compilationUnit = parseCompilationUnit(file.readAsStringSync());
  final collector = _LibrarySummaryCollector(relativePath);
  compilationUnit.accept(collector);
  return collector.summarize();
}

class _LibrarySummary {
  _LibrarySummary({
    @required this.relativePath,
    @required this.classes,
    @required this.functionNames,
    @required this.variableNames,
  });

  final String relativePath;
  final List<_ClassSummary> classes;
  final List<String> functionNames;
  final List<String> variableNames;

  bool containsClass(String className) {
    return classes.map((s) => s.className).any((name) => name == className);
  }

  _LibraryDelta deltaFrom(_LibrarySummary other) {
    var classDelta = _diffStringLists(
      classes.map<String>((c) => c.className).toList(),
      other.classes.map<String>((c) => c.className).toList(),
    );

    var functionDelta = _diffStringLists(
      functionNames,
      other.functionNames,
    );

    var variableDelta = _diffStringLists(
      variableNames,
      other.variableNames,
    );

    return _LibraryDelta(classDelta, functionDelta, variableDelta);
  }
}

class _LibraryDelta {
  _LibraryDelta(this.classDelta, this.functionDelta, this.variableDelta);

  final _StringListDiff classDelta;
  final _StringListDiff functionDelta;
  final _StringListDiff variableDelta;

  bool get isDifferent =>
      classDelta.isDifferent ||
      functionDelta.isDifferent ||
      variableDelta.isDifferent;
}

class _ClassSummary {
  _ClassSummary({
    this.className,
    this.fieldNames,
    this.methodNames,
  });

  final String className;
  final List<String> fieldNames;
  final List<String> methodNames;
}

class _LibrarySummaryCollector extends RecursiveAstVisitor<void> {
  _LibrarySummaryCollector(this.relativePath);

  final String relativePath;
  final List<_ClassSummary> classes = <_ClassSummary>[];
  final List<String> functionNames = <String>[];
  final List<String> variableNames = <String>[];

  String className;
  List<String> fieldNames;
  List<String> methodNames;

  _LibrarySummary summarize() {
    _flushLatestClassData();
    return _LibrarySummary(
      relativePath: relativePath,
      classes: classes,
      functionNames: functionNames,
      variableNames: variableNames,
    );
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _flushLatestClassData();

    if (node.name.name.startsWith('_')) {
      // Skip private members
      return;
    }

    className = node.name.name;
    methodNames = <String>[];
    fieldNames = <String>[];
    super.visitClassDeclaration(node);
  }

  void _flushLatestClassData() {
    if (className != null) {
      classes.add(_ClassSummary(
        className: className,
        fieldNames: fieldNames,
        methodNames: methodNames,
      ));
      className = null;
      methodNames = null;
      fieldNames = null;
    }
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.name.name.startsWith('_')) {
      // Skip private members
      return;
    }

    functionNames.add(node.name.name);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.name.name.startsWith('_')) {
      // Skip private members
      return;
    }

    variableNames.add(node.name.name);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.name.startsWith('_')) {
      // Skip private members
      return;
    }

    methodNames.add(node.name.name);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    final fieldNameExtractor = _FieldNameExtractor();
    node.fields.accept(fieldNameExtractor);

    // Could be empty if all fields in the group are private.
    if (fieldNameExtractor.names.isNotEmpty) {
      fieldNames.addAll(fieldNameExtractor.names);
    }
  }
}

class _FieldNameExtractor extends SimpleAstVisitor<void> {
  final List<String> names = <String>[];

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.name.name.startsWith('_')) {
      // Skip private members
      return;
    }

    names.add(node.name.name);
  }
}
