// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.


import 'descriptor.dart' as d;
import 'test_pub.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pub/src/barback.dart' as barback;

main() {
  initConfig();

  forBothPubGetAndUpgrade((command) {
    integration("implicitly constrains it to versions pub supports", () {
      servePackages((builder) {
        builder.serve("barback", current("barback"));
        builder.serve("stack_trace", previous("stack_trace"));
        builder.serve("stack_trace", current("stack_trace"));
        builder.serve("stack_trace", nextPatch("stack_trace"));
        builder.serve("stack_trace", max("stack_trace"));
        builder.serve("source_span", current("source_span"));
      });

      d.appDir({
        "barback": "any"
      }).create();

      pubCommand(command);

      d.packagesDir({"stack_trace": nextPatch("stack_trace")}).validate();
    });

    integration("pub's implicit constraint uses the same source and "
        "description as a dependency override", () {
      servePackages((builder) {
        builder.serve("barback", current("barback"));
        builder.serve("stack_trace", nextPatch("stack_trace"));
        builder.serve("source_span", current("source_span"));
      });

      d.dir("stack_trace", [
        d.libDir("stack_trace", 'stack_trace ${current("stack_trace")}'),
        d.libPubspec("stack_trace", current("stack_trace"))
      ]).create();

      d.dir(appPath, [
        d.pubspec({
          "name": "myapp",
          "dependencies": {"barback": "any"},
          "dependency_overrides": {
            "stack_trace": {"path": "../stack_trace"},
          }
        })
      ]).create();

      pubCommand(command);

      // Validate that we're using the path dependency version of stack_trace
      // rather than the hosted version.
      d.packagesDir({
        "stack_trace": current("stack_trace")
      }).validate();
    });

    integration("doesn't add a constraint if barback isn't in the package "
        "graph", () {
      servePackages((builder) {
        builder.serve("stack_trace", previous("stack_trace"));
        builder.serve("stack_trace", current("stack_trace"));
        builder.serve("stack_trace", nextPatch("stack_trace"));
        builder.serve("stack_trace", max("stack_trace"));
        builder.serve("source_span", current("source_span"));
      });

      d.appDir({
        "stack_trace": "any"
      }).create();

      pubCommand(command);

      d.packagesDir({"stack_trace": max("stack_trace")}).validate();
    });
  });

  integration("unlocks if the locked version doesn't meet pub's "
      "constraint", () {
    servePackages((builder) {
      builder.serve("barback", current("barback"));
      builder.serve("stack_trace", previous("stack_trace"));
      builder.serve("stack_trace", current("stack_trace"));
      builder.serve("source_span", current("source_span"));
    });

    d.appDir({"barback": "any"}).create();

    // Hand-create a lockfile to pin the package to an older version.
    createLockFile("myapp", hosted: {
      "barback": current("barback"),
      "stack_trace": previous("stack_trace")
    });

    pubGet();

    // It should be upgraded.
    d.packagesDir({
      "stack_trace": current("stack_trace")
    }).validate();
  });
}

String current(String packageName) =>
    barback.pubConstraints[packageName].min.toString();

String previous(String packageName) {
  var constraint = barback.pubConstraints[packageName];
  return new Version(constraint.min.major, constraint.min.minor - 1, 0)
      .toString();
}

String nextPatch(String packageName) =>
    barback.pubConstraints[packageName].min.nextPatch.toString();

String max(String packageName) =>
    barback.pubConstraints[packageName].max.toString();
