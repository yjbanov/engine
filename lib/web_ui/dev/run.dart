// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:args/command_runner.dart';

import 'common.dart';
import 'utils.dart';

import 'steps/compile_tests_step.dart';
import 'steps/run_tests_step.dart';
import 'watcher.dart';

/// Runs build and test steps.
///
/// This command is designed to be invoked by the LUCI build graph. However, it
/// is also usable locally.
///
/// Usage:
///
///     felt run name_of_build_step
class RunCommand extends Command<bool> with ArgUtils<bool> {
  RunCommand() {
    argParser
      ..addFlag(
        'list',
        abbr: 'l',
        defaultsTo: false,
        help: 'Lists all available build steps.',
      );
  }

  @override
  String get name => 'run';

  bool get isListSteps => boolArg('list');

  @override
  String get description => 'Runs a build step.';

  /// Build steps to run, in order specified.
  List<String> get stepNames => argResults!.rest;

  @override
  FutureOr<bool> run() async {
    // All available build steps.
    final Map<String, PipelineStep> buildSteps = <String, PipelineStep>{
      'compile_tests': CompileTestsStep(),
      for (final String browserName in kAllBrowserNames)
        'run_tests_$browserName': RunTestsStep(
          browserEnvironment: getBrowserEnvironment(browserName),
          isDebug: false,
          doUpdateScreenshotGoldens: false,
        ),
    };

    if (isListSteps) {
      for (final String stepName in buildSteps.keys) {
        print(stepName);
      }
      return true;
    }

    if (stepNames.isEmpty) {
      throw UsageException('No build steps specified.', argParser.usage);
    }

    final List<String> unrecognizedStepNames = <String>[];
    for (String stepName in stepNames) {
      if (!buildSteps.containsKey(stepName)) {
        unrecognizedStepNames.add(stepName);
      }
    }
    if (unrecognizedStepNames.isNotEmpty) {
      io.stderr.writeln();
      return false;
    }

    final List<PipelineStep> steps = <PipelineStep>[];
    for (String stepName in stepNames) {
      steps.add(buildSteps[stepName]!);
    }

    final Pipeline pipeline = Pipeline(steps: steps);
    await pipeline.run();

    return true;
  }
}
