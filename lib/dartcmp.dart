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
import 'package:analyzer/analyzer.dart';

class StringListDiff {
  factory StringListDiff.between(List<String> a, List<String> b) {
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

    return StringListDiff(missing, extra, matching);
  }

  StringListDiff(this.missing, this.extra, this.matching);

  final List<String> missing;
  final List<String> extra;
  final List<String> matching;

  bool get isDifferent => missing.isNotEmpty || extra.isNotEmpty;
}

class LibrarySummary {
  LibrarySummary({
    @required this.relativePath,
    @required this.classes,
    @required this.functionNames,
    @required this.variableNames,
  });

  final String relativePath;
  final List<ClassSummary> classes;
  final List<String> functionNames;
  final List<String> variableNames;

  static LibrarySummary parse(io.File file, {String relativePath}) {
    final compilationUnit = parseCompilationUnit(file.readAsStringSync());
    final collector = _LibrarySummaryCollector(relativePath);
    compilationUnit.accept(collector);
    return collector.summarize();
  }

  bool containsClass(String className) {
    return classes.map((s) => s.className).any((name) => name == className);
  }
}

class LibraryDelta {
  factory LibraryDelta.between(LibrarySummary a, LibrarySummary b) {
    var classDelta = StringListDiff.between(
      a.classes.map<String>((c) => c.className).toList(),
      b.classes.map<String>((c) => c.className).toList(),
    );

    var functionDelta = StringListDiff.between(
      a.functionNames,
      b.functionNames,
    );

    var variableDelta = StringListDiff.between(
      a.variableNames,
      b.variableNames,
    );

    return LibraryDelta(classDelta, functionDelta, variableDelta);
  }

  LibraryDelta(this.classDelta, this.functionDelta, this.variableDelta);

  final StringListDiff classDelta;
  final StringListDiff functionDelta;
  final StringListDiff variableDelta;

  bool get isDifferent =>
      classDelta.isDifferent ||
      functionDelta.isDifferent ||
      variableDelta.isDifferent;
}

class ClassSummary {
  ClassSummary({
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
  final List<ClassSummary> classes = <ClassSummary>[];
  final List<String> functionNames = <String>[];
  final List<String> variableNames = <String>[];

  String className;
  List<String> fieldNames;
  List<String> methodNames;

  LibrarySummary summarize() {
    _flushLatestClassData();
    return LibrarySummary(
      relativePath: relativePath,
      classes: classes,
      functionNames: functionNames,
      variableNames: variableNames,
    );
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (_visitClassOrMixinDeclaration(node)) {
      super.visitClassDeclaration(node);
    }
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    if (_visitClassOrMixinDeclaration(node)) {
      super.visitMixinDeclaration(node);
    }
  }

  bool _visitClassOrMixinDeclaration(ClassOrMixinDeclaration node) {
    _flushLatestClassData();

    if (node.name.name.startsWith('_')) {
      // Skip private members
      return false;
    }

    className = node.name.name;
    methodNames = <String>[];
    fieldNames = <String>[];
    return true;
  }

  void _flushLatestClassData() {
    if (className != null) {
      classes.add(ClassSummary(
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
