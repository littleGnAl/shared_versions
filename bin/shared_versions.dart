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

import 'package:args/args.dart';
import 'package:shared_versions/src/versions_synchronizer.dart';

/// CLI tool that help match the package dependencies versions from
/// the `shared_versions.yaml` to the `pubspec.yaml` file by default.
/// You can also specify which versions file you use by passing
/// the `--path`/`-p` option, e.g.,
/// ```
/// pub run shared_versions --path your_versions.yaml
/// ```
void main(List<String> arguments) {
  final parser = ArgParser();
  parser.addOption("path",
      abbr: "p",
      defaultsTo: "shared_versions.yaml",
      help: "The path of the versions file, which should be a yaml file");

  final results = parser.parse(arguments);
  if ((results.rest.isNotEmpty) || !results["path"].endsWith(".yaml")) {
    stderr.writeln(parser.usage);
    return;
  }

  final versionsFilePath = results["path"];
  final versionsFile = File(versionsFilePath);
  if (!versionsFile.existsSync()) {
    stderr.writeln("The file of path \"${results["path"]}\" is not exist.");
    return;
  }

  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln("The \"pubspec.yaml}\" file is not exist.");
    return;
  }
  VersionsSynchronizer(stdout, versionsFile).syncTo(pubspecFile);
}
