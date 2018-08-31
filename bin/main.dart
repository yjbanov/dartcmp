import 'dart:io' as io;

import 'package:args/args.dart' as arg;
import 'package:path/path.dart' as path_lib;

String aPath;
String bPath;

void main(List<String> rawArgs) {
  final argp = arg.ArgParser()
    ..addOption('a', help: 'path to the first Dart package')
    ..addOption('b', help: 'path to the second Dart package');
  final args = argp.parse(rawArgs);
  aPath = args['a'];
  bPath = args['b'];
  final aDir = io.Directory(args['a']);
  final bDir = io.Directory(args['b']);
  compareDirectories(aDir, bDir);
}

void compareDirectories(io.Directory a, io.Directory b) {
  final aList = a.listSync();
  final bList = b.listSync();
  compareFiles(dartFiles(aList), dartFiles(bList));
  compareDirectoryLists(directories(aList), directories(bList));
}

void compareDirectoryLists(Map<String, io.Directory> aDirs, Map<String, io.Directory> bDirs) {
  bDirs.forEach((String name, io.Directory bDir) {
    if (!aDirs.containsKey(name)) {
      print('Directory ${path_lib.relative(bDir.path, from: bPath)} not ported');
      return;
    }

    compareDirectories(aDirs[name], bDir);
  });

  aDirs.forEach((String name, io.Directory aDir) {
    if (!bDirs.containsKey(name)) {
      print('Extra directory ${path_lib.relative(aDir.path, from: aPath)}');
      return;
    }
  });
}

void compareFiles(Map<String, io.File> aFiles, Map<String, io.File> bFiles) {
  bFiles.forEach((String name, io.File bFile) {
    if (!aFiles.containsKey(name)) {
      print('${path_lib.relative(bFile.path, from: bPath)} not ported');
      return;
    }

    // TODO(yjbanov): parse and compare contents
  });

  aFiles.forEach((String name, io.File aFile) {
    if (!bFiles.containsKey(name)) {
      print('${path_lib.relative(aFile.path, from: aPath)} extra file');
      return;
    }
  });
}

Map<String, io.File> dartFiles(List<io.FileSystemEntity> listing) =>
    Map.fromIterable(
      listing.whereType<io.File>().where((f) => f.path.endsWith('.dart')),
      key: (f) => path_lib.basename(f.path),
    );

Map<String, io.Directory> directories(List<io.FileSystemEntity> listing) =>
    Map.fromIterable(
      // ignore hidden stuff
      listing.whereType<io.Directory>().where((d) => !d.path.startsWith('.')),
      key: (d) => path_lib.basename(d.path),
    );
