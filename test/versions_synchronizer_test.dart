// Copyright (C) 2020 littlegnal
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
// import 'dart:io';

import 'dart:io';

import 'package:ansicolor/ansicolor.dart' as ansicolor;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_versions/src/versions_synchronizer.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';

import 'versions_synchronizer_test.mocks.dart';

@GenerateMocks([],
    customMocks: [MockSpec<Stdout>(returnNullOnMissingStub: true)])
void main() {
  ansicolor.ansiColorDisabled = true;
  late Stdout mockStdout;
  late File versionsFile;
  late File pubspecFile;
  late VersionsSynchronizer versionsSynchronizer;

  setUp(() {
    mockStdout = MockStdout();

    final fileSystem = MemoryFileSystem();

    versionsFile = fileSystem.file('shared_versions.yaml');
    versionsFile.createSync(recursive: true);
    pubspecFile = fileSystem.file('pubspec.yaml');
    pubspecFile.createSync(recursive: true);

    versionsSynchronizer = VersionsSynchronizer(mockStdout, versionsFile);
  });

  // https://dart.dev/tools/pub/dependencies
  group("VersionsSynchronizer map2Lines", () {
    test("hosted packages", () {
      final map = YamlMap.wrap({
        "hosted": {
          "name": "transmogrify",
          "url": "http://your-package-server.com",
        },
        "version": "^1.4.0",
      });
      final expectedLines = 'transmogrify:\n'
          '  hosted:\n'
          '    name: transmogrify\n'
          '    url: http://your-package-server.com\n'
          '  version: ^1.4.0\n';

      final lines = versionsSynchronizer.map2Lines("transmogrify", 0, 0, map);
      expect(lines, expectedLines);
    });

    test("hosted packages without version", () {
      final map = YamlMap.wrap({
        "hosted": {
          "name": "transmogrify",
          "url": "http://your-package-server.com",
        },
      });
      final expectedLines = 'transmogrify:\n'
          '  hosted:\n'
          '    name: transmogrify\n'
          '    url: http://your-package-server.com\n';

      final lines = versionsSynchronizer.map2Lines("transmogrify", 0, 0, map);
      expect(lines, expectedLines);
    });

    test("git packages", () {
      final map =
          YamlMap.wrap({"git": "git://github.com/munificent/kittens.git"});
      final expectedLines = 'kittens:\n'
          '  git: git://github.com/munificent/kittens.git\n';

      final lines = versionsSynchronizer.map2Lines("kittens", 0, 0, map);
      expect(lines, expectedLines);
    });

    test("git packages with url, ref", () {
      final map = YamlMap.wrap({
        "git": {
          "url": "git://github.com/munificent/kittens.git",
          "ref": "some-branch",
        }
      });
      final expectedLines = 'kittens:\n'
          '  git:\n'
          '    url: git://github.com/munificent/kittens.git\n'
          '    ref: some-branch\n';

      final lines = versionsSynchronizer.map2Lines("kittens", 0, 0, map);
      expect(lines, expectedLines);
    });

    test("path packages", () {
      final map = YamlMap.wrap({"path": "/Users/me/transmogrify"});
      final expectedLines = 'transmogrify:\n'
          '  path: /Users/me/transmogrify\n';

      final lines = versionsSynchronizer.map2Lines("transmogrify", 0, 0, map);
      expect(lines, expectedLines);
    });
  });

  group("VersionsSynchronizer syncTo", () {
    test("change versions of pub packages", () {
      final versionsFileContent = 'built_collection: ^4.3.1';
      final pubspecFileContent = 'dependencies:\n'
          '  built_collection: 4.3.2';
      final expectedPubspecFileContent = 'dependencies:\n'
          '  built_collection: ^4.3.1\n';

      versionsFile.writeAsStringSync(versionsFileContent);

      pubspecFile.writeAsStringSync(pubspecFileContent);

      versionsSynchronizer.syncTo(pubspecFile);

      expect(pubspecFile.readAsStringSync(), expectedPubspecFileContent);
    });

    test("change versions of pub packages with comment", () {
      final versionsFileContent = 'built_collection: ^4.3.1';
      final pubspecFileContent = 'dependencies:\n'
          '  # built_collection: 4.3.2\n'
          '  built_collection: 4.3.2';
      final expectedPubspecFileContent = 'dependencies:\n'
          '  # built_collection: 4.3.2\n'
          '  built_collection: ^4.3.1\n';

      versionsFile.writeAsStringSync(versionsFileContent);
      pubspecFile.writeAsStringSync(pubspecFileContent);
      versionsSynchronizer.syncTo(pubspecFile);

      expect(pubspecFile.readAsStringSync(), expectedPubspecFileContent);
    });

    test("change versions of pub packages with comment", () {
      final versionsFileContent = 'built_collection: ^4.3.1';
      final pubspecFileContent = 'dependencies:\n'
          '  # built_collection: 4.3.2\n'
          '  built_collection: 4.3.2';
      final expectedPubspecFileContent = 'dependencies:\n'
          '  # built_collection: 4.3.2\n'
          '  built_collection: ^4.3.1\n';
      versionsFile.writeAsStringSync(versionsFileContent);
      pubspecFile.writeAsStringSync(pubspecFileContent);
      versionsSynchronizer.syncTo(pubspecFile);

      expect(pubspecFile.readAsStringSync(), expectedPubspecFileContent);
    });

    test("change git packages to path packages", () {
      final versionsFileContent = 'assets_scanner:\n'
          '  path: ../';
      final pubspecFileContent = 'dependencies:\n'
          '  assets_scanner:\n'
          '    git:\n'
          '      url: https://github.com/littleGnAl/assets-scanner.git\n'
          '      ref: master';
      final expectedPubspecFileContent = 'dependencies:\n'
          '  assets_scanner:\n'
          '    path: ../\n';
      versionsFile.writeAsStringSync(versionsFileContent);
      pubspecFile.writeAsStringSync(pubspecFileContent);
      versionsSynchronizer.syncTo(pubspecFile);

      expect(pubspecFile.readAsStringSync(), expectedPubspecFileContent);
    });

    test("change path packages to git packages", () {
      final versionsFileContent = 'assets_scanner:\n'
          '  git:\n'
          '    url: https://github.com/littleGnAl/assets-scanner.git\n'
          '    ref: master';
      final pubspecFileContent = 'dependencies:\n'
          '  assets_scanner:\n'
          '    path: ../';
      final expectedPubspecFileContent = 'dependencies:\n'
          '  assets_scanner:\n'
          '    git:\n'
          '      url: https://github.com/littleGnAl/assets-scanner.git\n'
          '      ref: master\n';
      versionsFile.writeAsStringSync(versionsFileContent);
      pubspecFile.writeAsStringSync(pubspecFileContent);
      versionsSynchronizer.syncTo(pubspecFile);

      expect(pubspecFile.readAsStringSync(), expectedPubspecFileContent);
    });
  });

  group("VersionsSynchronizer syncTo stdout", () {
    test("change versions of pub packages", () async {
      final versionsFileContent = 'built_collection: ^4.3.1';
      final pubspecFileContent = 'dependencies:\n'
          '  built_collection: 4.3.2';
      final expectedPubspecFileContent =
          'built_collection: 4.3.2 -> built_collection: ^4.3.1';
      versionsFile.writeAsStringSync(versionsFileContent);

      pubspecFile.writeAsStringSync(pubspecFileContent);
      versionsSynchronizer.syncTo(pubspecFile);
      verify(mockStdout.writeln(expectedPubspecFileContent));
    });

    test("same versions of pub packages", () async {
      final versionsFileContent = 'built_collection: 4.3.2';
      final pubspecFileContent = 'dependencies:\n'
          '  built_collection: 4.3.2';
      versionsFile.writeAsStringSync(versionsFileContent);

      pubspecFile.writeAsStringSync(pubspecFileContent);
      versionsSynchronizer.syncTo(pubspecFile);
      verifyNever(mockStdout
          .writeln("built_collection: 4.3.2 -> built_collection: 4.3.2"));
    });

    test("change git packages to path packages", () {
      final versionsFileContent = 'assets_scanner:\n'
          '  path: ../';
      final pubspecFileContent = 'dependencies:\n'
          '  assets_scanner:\n'
          '    git:\n'
          '      url: https://github.com/littleGnAl/assets-scanner.git\n'
          '      ref: master';
      final expectedPubspecFileContent =
          'assets_scanner:                                           -> assets_scanner:\n'
          '  git:                                                         path: ../\n'
          '    url: https://github.com/littleGnAl/assets-scanner.git\n'
          '    ref: master\n';

      versionsFile.writeAsStringSync(versionsFileContent);
      pubspecFile.writeAsStringSync(pubspecFileContent);
      versionsSynchronizer.syncTo(pubspecFile);
      verify(mockStdout.write(expectedPubspecFileContent));
    });

    test("same version of git packages", () {
      final versionsFileContent = 'assets_scanner:\n'
          '  path: ../';
      final pubspecFileContent = 'dependencies:\n'
          '  assets_scanner:\n'
          '    git:\n'
          '      url: https://github.com/littleGnAl/assets-scanner.git\n'
          '      ref: master';
      final expectedPubspecFileContent =
          'assets_scanner:                                           -> assets_scanner:\n'
          '  git:                                                         git:\n'
          '    url: https://github.com/littleGnAl/assets-scanner.git        url: https://github.com/littleGnAl/assets-scanner.git\n'
          '    ref: master                                                  ref: master\n';
      versionsFile.writeAsStringSync(versionsFileContent);
      pubspecFile.writeAsStringSync(pubspecFileContent);
      versionsSynchronizer.syncTo(pubspecFile);
      verifyNever(mockStdout.write(expectedPubspecFileContent));
    });

    test("change path packages to git packages", () {
      final versionsFileContent = 'assets_scanner:\n'
          '  git:\n'
          '    url: https://github.com/littleGnAl/assets-scanner.git\n'
          '    ref: master';
      final pubspecFileContent = 'dependencies:\n'
          '  assets_scanner:\n'
          '    path: ../';
      final expectedPubspecFileContent = 'assets_scanner: -> assets_scanner:\n'
          '  path: ../          git:\n'
          '                       url: https://github.com/littleGnAl/assets-scanner.git\n'
          '                       ref: master\n';
      versionsFile.writeAsStringSync(versionsFileContent);

      pubspecFile.writeAsStringSync(pubspecFileContent);
      versionsSynchronizer.syncTo(pubspecFile);
      verify(mockStdout.write(expectedPubspecFileContent));
    });

    test("same version of path packages", () {
      final versionsFileContent = 'assets_scanner:\n'
          '  git:\n'
          '    url: https://github.com/littleGnAl/assets-scanner.git\n'
          '    ref: master';
      final pubspecFileContent = 'dependencies:\n'
          '  assets_scanner:\n'
          '    path: ../';
      final expectedPubspecFileContent = 'assets_scanner: -> assets_scanner:\n'
          '  path: ../          path: ../\n';
      versionsFile.writeAsStringSync(versionsFileContent);

      pubspecFile.writeAsStringSync(pubspecFileContent);
      versionsSynchronizer.syncTo(pubspecFile);
      verifyNever(mockStdout.write(expectedPubspecFileContent));
    });
  });
}
