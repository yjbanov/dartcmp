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

import 'package:args/args.dart' as arg;

import 'package:dartcmp/dartcmp.dart';

/// Lists the contents of a given library.
void main(List<String> rawArgs) {
  final argp = arg.ArgParser()
    ..addOption('l', help: 'path to the Dart library to list');
  final args = argp.parse(rawArgs);

  final io.File libraryFile = io.File(args['l']);
  final LibrarySummary summary = LibrarySummary.parse(libraryFile);
  for (ClassSummary clazz in summary.classes) {
    print(clazz.className);
  }
}
