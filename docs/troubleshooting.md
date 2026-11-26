<!-- ----------------------------------------------------------------------------
  Copyright (c) 2026 Contributors to the Eclipse Foundation

  See the NOTICE file(s) distributed with this work for additional
  information regarding copyright ownership.

  This program and the accompanying materials are made available under the
  terms of the Apache License Version 2.0 which is available at
  https://www.apache.org/licenses/LICENSE-2.0

  SPDX-License-Identifier: Apache-2.0
----------------------------------------------------------------------------- -->

# Troubleshooting

This page lists error messages that you can get when you use the module, with
the cause and the fix for each.

## No matching toolchains found

**Message:**

```text
ERROR: While resolving toolchains for target //:my_image: No matching toolchains found for types:
  @@score_rules_imagefs+//toolchains/linux:ext4_toolchain_type
```

For QNX rules, the type in the message is one of the `toolchains/qnx` types,
for example `ifs_toolchain_type`.

**Cause:** Bazel found no registered toolchain for the rule. The module
registers none by default. Another cause is a registered toolchain whose
constraints don't match your build. The `ext4` toolchain, for example, needs
an x86_64 Linux execution platform and a target platform that matches
`target_cpu` and `target_os`.

**Fix:**

1. Declare a toolchain with the `imagefs` extension, and call
   `use_repo` for it. See [Configure toolchains](toolchains.md).
1. Register it with `register_toolchains`, or pass it with
   `--extra_toolchains`.
1. To see why Bazel rejected a toolchain, rebuild with
   `--toolchain_resolution_debug` and the toolchain type from the message:

   ```shell
   bazel build //:my_image --toolchain_resolution_debug='@@score_rules_imagefs+//toolchains/linux:ext4_toolchain_type'
   ```

## Only the root module can use the 'imagefs' extension

**Cause:** A module other than the root module of the build uses the `imagefs`
extension.

**Fix:** Move the `use_extension`, `imagefs.toolchain`, and `use_repo` calls to
the `MODULE.bazel` of the root module. Dependencies shouldn't declare
toolchains.

## Target does not provide a rules_pkg provider

**Message:**

```text
Target //:my_target does not provide a rules_pkg provider
```

The QNX rules say `does not provide any rules_pkg provider`.

**Cause:** A label in `srcs` isn't a `rules_pkg` target, for example a plain
file or a generated image.

**Fix:** Wrap the files with `pkg_files`, or use `pkg_mkdirs`, `pkg_mklink`, or
`pkg_filegroup`. See [Rule reference](rules.md#the-srcs-attribute).

## Output file must be a filename without path components

**Cause:** The `out` attribute contains a `/`.

**Fix:** Set `out` to a plain file name, such as `rootfs.ext4`. To change the
directory, set the target's package, not `out`.

## The QNX kernel crashes when it boots in QEMU

**Message:** The serial output ends with a register dump after this line:

```text
WARNING: Too early for per-cpu data
```

**Cause:** You started QEMU with `-cpu host` and KVM. QNX 8.0 can't boot with
the host CPU model that QEMU passes to the guest.

**Fix:** Set a named CPU model, for example `-cpu Cascadelake-Server-v5`. See
[Boot an IFS image in QEMU](qnx-images.md#boot-an-ifs-image-in-qemu).

## The IFS image boots but the program doesn't run

**Message:** The serial output contains lines like these:

```text
ldd:FATAL: Could not load library libsecpol.so.1
Unable to access "/dev/ser1" (2)
```

**Cause:** A shared library that a program needs isn't in the image. In the
example, the serial driver `devc-ser8250` can't start without `libsecpol.so.1`,
so `/dev/ser1` doesn't exist and the startup script can't reach your program.

**Fix:**

1. Run `readelf -d` on the program that failed, and read the `NEEDED` lines.
1. Add each listed library to the boot file. Repeat for the libraries that
   those libraries need.

## The QNX SDP download fails

**Cause:** The SDP 8.0.5 archive that `score_bazel_cpp_toolchains` downloads is
a GitHub release asset, and the download needs a token. Bazel finds no token.

**Fix:** Set `GH_TOKEN`, `GITHUB_TOKEN`, or `SCORE_GITHUB_TOKEN` to a token with
read access to the `eclipse-score/qnx_sdp_pkg` repository, or add a
`github.com` or `api.github.com` entry to your `~/.netrc` file. After the first
download, Bazel uses its cache.

## Bazel can't find a module

**Cause:** Your `.bazelrc` doesn't list the S-CORE registry. Modules such as
`score_bazel_platforms` and `score_tools` come from that registry, and Bazel
reads registries only from the root module's `.bazelrc`.

**Fix:** Add both registries to your `.bazelrc`:

```text
common --registry=https://raw.githubusercontent.com/eclipse-score/bazel_registry/main/
common --registry=https://bcr.bazel.build
```

## The ext4 build can't download or compile `mke2fs`

**Cause:** The first `ext4` build downloads the e2fsprogs source from GitHub
and compiles it with the host C toolchain. The build fails if the machine has
no network access to `github.com` or no C compiler.

**Fix:** Allow access to `github.com`, or provide the source through a Bazel
repository cache or mirror. Install a C compiler. If you can't build from
source, define the toolchain yourself with prebuilt tools. See
[Define an ext4 toolchain yourself](toolchains.md#define-an-ext4-toolchain-yourself).

## The ext4 test reports `debugfs: command not found`

**Cause:** The test in this repository inspects the image with `debugfs` and
`tune2fs` from the host.

**Fix:** Install the e2fsprogs package on the machine that runs the test. For
example, on Debian or Ubuntu, run `sudo apt install e2fsprogs`.
