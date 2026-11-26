<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

# Development guide

This guide is for contributors to `rules_imagefs`. It explains the repository
layout and how to run the tests, formatting, and license checks. To learn how
the module works, read [How it works](how-it-works.md) first.

## Repository layout

| Path | Content |
|---|---|
| [extensions/](../extensions) | The `imagefs` module extension. |
| [rules/](../rules) | Image rules, the toolchain repository rule, and helper tools. |
| [toolchains/](../toolchains) | Toolchain types and toolchain config rules. |
| [templates/](../templates) | `BUILD` templates for generated toolchain repositories and for building `mke2fs`. |
| [tests/](../tests) | A separate Bazel module that uses this repository as a dependency. It has one directory for each platform and image type: [linux/ext4/](../tests/linux/ext4) and [qnx/ifs/](../tests/qnx/ifs). |
| [docs/](.) | This documentation. |
| [NOTICE](../NOTICE) | Third-party content that the module fetches and builds. |

## Before you begin

- Use an x86_64 Linux machine. Bazel 8.8.2 is selected by
  [.bazelversion](../.bazelversion); Bazelisk downloads it for you.
- Install a C compiler and the e2fsprogs package. The ext4 test compiles
  `mke2fs` and calls `debugfs` and `tune2fs` from the host.
- To run the QNX IFS test, you also need:
  - `qemu-system-x86_64` in your `PATH`.
  - A QNX license file at `/opt/score_qnx/license/licenses`.
  - Access to the QNX SDP 8.0.5 archive, which is a GitHub release asset in
    the `eclipse-score/qnx_sdp_pkg` repository. The download needs a token
    with read access. Set `GH_TOKEN`, `GITHUB_TOKEN`, or
    `SCORE_GITHUB_TOKEN`, or add a `github.com` or `api.github.com` entry to
    your `~/.netrc` file. After the first download, Bazel uses its cache.
  - Optional: write access to `/dev/kvm`. Without it, QEMU uses software
    emulation, which is slower but works.

## Run the tests

The tests are in a nested module, [tests/](../tests). It depends on the
repository through `local_path_override`, and it declares an ext4 toolchain, a
QNX IFS toolchain, and the QNX C++ toolchain from `score_bazel_cpp_toolchains`.

Each test needs its own build configuration, and Bazel skips the tests of the
other platform. To run a test:

1. Change to the test module:

   ```shell
   cd tests
   ```

1. Run the test that you want:

   - To run the ext4 test:

     ```shell
     bazel test --config=x86_64-linux-ext4 //...
     ```

   - To run the QNX IFS test:

     ```shell
     bazel test --config=x86_64-qnx-ifs //...
     ```

   The configurations in [tests/.bazelrc](../tests/.bazelrc) register the
   toolchains and, for QNX, select the QNX platform. Without the ext4
   configuration, the ext4 test fails with `No matching toolchains found`.
   Without the QNX configuration, Bazel skips the QNX test.

1. Confirm that the output lists the test as `PASSED`, for example
   `//linux/ext4:ext4_test` or `//qnx/ifs:ifs_test`. The test of the other
   platform shows `SKIPPED`.

### ext4 test

The `//linux/ext4:ext4_test` test builds an image from a file, a directory
artifact, and a symbolic link. It then uses `debugfs` and `tune2fs` to check the
file contents, the file types, the link target, and that the image has no
journal.

### QNX IFS test

The `//qnx/ifs:ifs_test` test builds an IFS image that contains a C program
that prints `hello from qnx ifs`, and boots the image in QEMU. The test passes
when the message appears on the serial console within 60 seconds. If it fails,
it prints the serial output.

The boot file, [image.build](../tests/qnx/ifs/image.build), is a minimal
example of an x86_64 boot image. To learn how to adapt it, see
[Boot an IFS image in QEMU](qnx-images.md#boot-an-ifs-image-in-qemu).

There are no automated tests for the `qnx6fs`, `fatfs`, and `diskimage` rules.

## Check formatting and copyright headers

From the repository root, run:

```shell
bazel test //:format.check
bazel run //:copyright.check
```

To fix formatting problems for Starlark, Python, and YAML files, run:

```shell
bazel run //:format.fix
```

To add missing copyright headers, run `bazel run //:copyright.fix`.

Every new file needs the Eclipse Foundation copyright header. Copy it from an
existing file of the same type.

## Update dependency versions

- Keep the dependency versions in [tests/MODULE.bazel](../tests/MODULE.bazel)
  the same as in the root [MODULE.bazel](../MODULE.bazel), so the tests exercise
  the versions that the module declares. The only difference is `rules_cc`,
  because `score_bazel_cpp_toolchains` requires a newer version than the root
  module declares.
- After you change a `MODULE.bazel` file, commit the matching
  `MODULE.bazel.lock` file. The CI workflow checks the lock file of the root
  module only, so also check `tests/MODULE.bazel.lock` yourself.

## Update e2fsprogs

1. In [extensions/imagefs.bzl](../extensions/imagefs.bzl), change `url`,
   `sha256`, and `strip_prefix` of the `e2fsprogs` repository.
1. Update the version and source URL in the "Third-party Content" section of
   [NOTICE](../NOTICE).
1. Run the ext4 test as described in [Run the tests](#run-the-tests).

## Continuous integration

The repository has three workflows in
[.github/workflows/](../.github/workflows). All of them run on pull requests
and on pushes to `main`. The two test workflows also run on merge queue
checks.

| Workflow | What it does |
|---|---|
| [checks.yml](../.github/workflows/checks.yml) | Runs the S-CORE copyright, formatting, and Bazel module lock file checks. |
| [ext4_test.yml](../.github/workflows/ext4_test.yml) | Runs `//linux/ext4:ext4_test` with the `x86_64-linux-ext4` configuration. |
| [qnx_ifs_test.yml](../.github/workflows/qnx_ifs_test.yml) | Runs `//qnx/ifs:ifs_test` with the `x86_64-qnx-ifs` configuration. |

The QNX workflow needs two secrets:

- `SCORE_QNX_LICENSE`: the QNX license file, encoded in Base64. The workflow
  writes it to `/opt/score_qnx/license/licenses` and deletes it at the end.
- `SCORE_BOT_QNX_PKG_PAT`: a token with read access to the SDP archive. The
  workflow passes it to Bazel as `GH_TOKEN`.

Pull requests from forks don't get secrets, so the QNX job doesn't run for
them. The workflow also installs QEMU and sets up KVM access, but the test
doesn't need KVM.
