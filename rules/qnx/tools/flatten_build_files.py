# *******************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Apache License Version 2.0 which is available at
# https://www.apache.org/licenses/LICENSE-2.0
#
# SPDX-License-Identifier: Apache-2.0
# *******************************************************************************
"""Concatenates diskimage build files, in order, into a single output file."""

import argparse


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("inputs", nargs="+")
    args = parser.parse_args()

    with open(args.output, "w", encoding="utf-8", newline="\n") as out:
        for path in args.inputs:
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
            out.write(content)
            if not content.endswith("\n"):
                out.write("\n")


if __name__ == "__main__":
    main()
