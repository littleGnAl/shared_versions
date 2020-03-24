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
import 'dart:math';

import 'package:ansicolor/ansicolor.dart';
import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart';

const _indent = 2;

/// Class that help match the package dependencies versions from [_versionsFile]
/// yaml file and override it to the other yaml file.
///
/// **NOTE:** This class only work for yaml file.
class VersionsSynchronizer {
  const VersionsSynchronizer(this._stdout, this._versionsFile);
  final Stdout _stdout;

  final File _versionsFile;

  /// Match the package dependencies versions from [_versionsFile] and override
  /// it the [pubspecFile].
  ///
  /// If the matched versions is different, it will print the changes to the console.
  void syncTo(File pubspecFile) {
    YamlMap versionsMap = loadYaml(_versionsFile.readAsStringSync());
    final pubspecMap = loadYaml(pubspecFile.readAsStringSync());
    StringBuffer newContent = StringBuffer();

    final pubspecFileLines = pubspecFile.readAsLinesSync();
    int lineIndex = 0;
    for (; lineIndex < pubspecFileLines.length;) {
      final line = pubspecFileLines[lineIndex];
      final trimLine = line.trim();

      // Skip comment the yaml list
      if (trimLine.startsWith("#") || !trimLine.contains(":")) {
        newContent.writeln(line);
        ++lineIndex;
        continue;
      }

      final key = trimLine.split(":").first.trim();
      if (versionsMap.containsKey(key)) {
        if (trimLine.endsWith(":")) {
          YamlMap versionsValue = versionsMap[key];
          YamlMap pubspecValue = _findMapByKey(key, pubspecMap);
          if (versionsValue.toString() != pubspecValue.toString()) {
            final versionsValueLines =
                map2Lines(key, line.indexOf(key), 0, versionsValue);
            newContent.write(versionsValueLines);

            _stdout.write(
                _createStdoutMessage(key, pubspecValue, key, versionsValue));

            final pubspecValueLineLength = _map2LinesCount(pubspecValue);
            lineIndex += pubspecValueLineLength + 1;
            continue;
          }
        } else {
          final newLine =
              line.substring(0, line.indexOf(":")) + ": " + versionsMap[key];
          final trimNewLine = newLine.trim();
          if (trimNewLine != trimLine) {
            newContent.writeln(newLine);
            _stdout.writeln(
                "${_textWithRemovedColor(trimLine)} -> ${_textWithAddedColor(trimNewLine)}");
            ++lineIndex;
            continue;
          }
        }
      }

      newContent.writeln(line);
      ++lineIndex;
    }

    pubspecFile.writeAsStringSync(newContent.toString());

    _stdout.writeln("Complete!");
  }

  @visibleForTesting
  String map2Lines(String key, int startIndent, int lineIndex, YamlMap map) {
    StringBuffer output = StringBuffer();
    final newKey = key + ":";
    output.writeln(
        newKey.padLeft(lineIndex * _indent + newKey.length + startIndent));
    final keys = map.keys;
    for (int i = 0; i < keys.length; i++) {
      final k = keys.elementAt(i);
      final value = map[k];
      String line;
      if (value is YamlMap) {
        line = "$k:";
        output.write(map2Lines(k, startIndent, lineIndex + i + 1, value));
      } else {
        line = "$k: $value";
        output.writeln(line
            .padLeft((lineIndex + 1) * _indent + line.length + startIndent));
        continue;
      }
    }

    return output.toString();
  }

  int _map2LinesCount(YamlMap map) {
    int sum = 0;
    final keys = map.keys;
    for (int i = 0; i < keys.length; i++) {
      final key = keys.elementAt(i);
      final value = map[key];
      if (value is YamlMap) {
        sum += 1 + _map2LinesCount(value);
      } else {
        sum += 1;
      }
    }

    return sum;
  }

  YamlMap _findMapByKey(String key, YamlMap map) {
    YamlMap result;
    final keys = map.keys;
    for (int i = 0; i < keys.length; i++) {
      final k = keys.elementAt(i);
      final v = map[k];

      if (k == key) {
        result = v;
        break;
      }
      if (v is YamlMap) {
        result = _findMapByKey(key, v);
        if (result != null) {
          break;
        }
      } else {
        continue;
      }
    }

    return result;
  }

  /// Create the stdout message for the changes, e.g.,
  /// ```
  /// assets_scanner:                                           -> assets_scanner:
  ///   git:                                                         path: ../
  ///     url: https://github.com/littleGnAl/assets-scanner.git
  ///     ref: master
  /// ```
  String _createStdoutMessage(
      String fromKey, YamlMap fromValue, String toKey, YamlMap toValue) {
    final fromLineLength = _map2LinesCount(fromValue) + 1;
    final toLineLength = _map2LinesCount(toValue) + 1;

    final length = max(fromLineLength, toLineLength);
    final fromLines = map2Lines(fromKey, 0, 0, fromValue);
    final fromLinesMaxLineLength = _findMaxLineLength(fromLines);
    final toLines = map2Lines(toKey, 0, 0, toValue);

    final fromLinesArr = fromLines.split("\n");
    final toLinesArr = toLines.split("\n");
    StringBuffer output = StringBuffer();
    final arrow = " -> ";
    for (int i = 0; i < length; i++) {
      String fromLine;
      if (i < fromLineLength) {
        fromLine = fromLinesArr[i];
        output.write(_textWithRemovedColor(fromLine));
      }

      if (i < toLineLength) {
        final toLine = toLinesArr[i];
        if (i == 0) {
          output.write(arrow.padLeft(
              fromLinesMaxLineLength + arrow.length - fromLine.length));
          output.write(_textWithAddedColor(toLine));
        } else {
          output.write(_textWithAddedColor(toLine.padLeft(
              fromLinesMaxLineLength +
                  toLine.length +
                  arrow.length -
                  (fromLine?.length ?? 0))));
        }
      }

      output.writeln();
    }

    return output.toString();
  }

  int _findMaxLineLength(String lines) {
    final linesArr = lines.split("\n");
    return linesArr.fold(0, (m, e) => max(m, e.length));
  }

  String _textWithRemovedColor(String text) {
    return (AnsiPen()..red())(text);
  }

  String _textWithAddedColor(String text) {
    return (AnsiPen()..green(bold: true))(text);
  }
}
