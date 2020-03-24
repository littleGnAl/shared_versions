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
import 'dart:io';

import 'package:test/test.dart';
import 'package:test_process/test_process.dart';

import 'package:path/path.dart' as p;

import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group("shared_versions", () {
    test("stderr not yaml file", () async {
      final process = await TestProcess.start(Platform.executable,
          ['bin/shared_versions.dart', '--path', 'versions.json']);
      await expectLater(
          process.stderrStream(),
          emitsInOrder(
            [
              '-p, --path    The path of the versions file, which should be a yaml file',
              '              (defaults to "shared_versions.yaml")'
            ],
          ));
    });

    test("shared_versions.yaml file exist", () async {
      await d.file("shared_versions.yaml").create();
      await d.file("pubspec.yaml").create();
      final dir = Directory.current.path;
      final process = await TestProcess.start(
          Platform.executable, [p.join(dir, 'bin/shared_versions.dart')],
          workingDirectory: d.sandbox);
      await expectLater(process.stderrStream(), emitsDone);
    });

    test("shared_versions.yaml file not exist", () async {
      final process = await TestProcess.start(
          Platform.executable, ['bin/shared_versions.dart']);
      await expectLater(process.stderrStream(),
          emits("The file of path \"shared_versions.yaml\" is not exist."));
    });

    test("pubspec.yaml file not exist", () async {
      await d.file("shared_versions.yaml").create();
      final dir = Directory.current.path;
      final process = await TestProcess.start(
          Platform.executable, [p.join(dir, 'bin/shared_versions.dart')],
          workingDirectory: d.sandbox);
      await expectLater(process.stderrStream(),
          emits("The \"pubspec.yaml}\" file is not exist."));
    });
  });
}
