"""Build-time code generation that upstream drives from the Makefiles.

Unlike the ./configure work in configure.bzl, these genuinely have to run at
execution time: they transform files whose contents Bazel cannot inspect during
analysis.

  lib/ext2fs/ext2_err.{c,h}   compile_et    (gawk over lib/et/et_[ch].awk)
  lib/support/prof_err.{c,h}  compile_et
  misc/default_profile.c      awk_to_source (misc/profile-to-c.awk)
  lib/ext2fs/crc32c_table.h   gen_header    (runs a host cc_binary)

`compile_et` skips upstream's compile_et shell wrapper and calls the two awk
scripts directly, the same way util/gen-android-files does. Because et_c.awk and
et_h.awk each write to the path named by their `outfile=` argument, these run as
plain ctx.actions.run with no shell.

awk_to_source and gen_header still need ctx.actions.run_shell: profile-to-c.awk
and gen_crc32ctable both printf to stdout, and Bazel cannot capture an action's
stdout without a shell redirect. Their arguments still come from
ctx.actions.args() and are referenced positionally, so no path is interpolated
into the command string.

awk comes from the gawk BCR module rather than $PATH, and no action sets
use_default_shell_env, so the client environment (notably LC_ALL, which changes
awk's numeric formatting) cannot leak in.
"""

_AWK = attr.label(
    default = "@gawk//:gawk_minimal",
    executable = True,
    cfg = "exec",
)

def _et_args(ctx, script, out, et):
    args = ctx.actions.args()
    args.add("-f", script)
    args.add(out, format = "outfile=%s")
    args.add(out.basename, format = "outfn=%s")
    args.add(et)
    return args

def _compile_et_impl(ctx):
    stem = ctx.attr.stem
    out_dir = ctx.attr.out_dir

    src = ctx.file.src
    if ctx.attr.version:
        # ext2_err.et.in carries @E2FSPROGS_VERSION@; upstream substitutes it
        # with util/subst before invoking compile_et.
        et = ctx.actions.declare_file("{}/{}.et".format(out_dir, stem))
        ctx.actions.expand_template(
            template = src,
            output = et,
            substitutions = {"@E2FSPROGS_VERSION@": ctx.attr.version},
        )
    else:
        et = src

    c_out = ctx.actions.declare_file("{}/{}.c".format(out_dir, stem))
    h_out = ctx.actions.declare_file("{}/{}.h".format(out_dir, stem))

    for script, out in [(ctx.file._et_c_awk, c_out), (ctx.file._et_h_awk, h_out)]:
        ctx.actions.run(
            executable = ctx.executable._awk,
            arguments = [_et_args(ctx, script, out, et)],
            inputs = [et, script],
            outputs = [out],
            mnemonic = "CompileEt",
            progress_message = "Generating %s" % out.basename,
        )

    return [
        DefaultInfo(files = depset([c_out, h_out])),
        OutputGroupInfo(
            srcs = depset([c_out]),
            hdrs = depset([h_out]),
        ),
    ]

compile_et = rule(
    implementation = _compile_et_impl,
    doc = "Runs the com_err error-table generator over a .et file.",
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "stem": attr.string(mandatory = True, doc = "Output basename, e.g. ext2_err."),
        "out_dir": attr.string(mandatory = True),
        "version": attr.string(
            doc = "If set, src is treated as a .et.in and @E2FSPROGS_VERSION@ " +
                  "is substituted.",
        ),
        "_et_c_awk": attr.label(allow_single_file = True, default = "//:lib/et/et_c.awk"),
        "_et_h_awk": attr.label(allow_single_file = True, default = "//:lib/et/et_h.awk"),
        "_awk": _AWK,
    },
)

def _awk_to_source_impl(ctx):
    out = ctx.actions.declare_file("{}/{}".format(ctx.attr.out_dir, ctx.attr.out_name))
    awk = ctx.executable._awk

    args = ctx.actions.args()
    args.add(awk)
    args.add(ctx.file.script)
    args.add(ctx.file.src)
    args.add(out)

    ctx.actions.run_shell(
        inputs = [ctx.file.script, ctx.file.src],
        tools = [awk],
        outputs = [out],
        command = '"$1" -f "$2" < "$3" > "$4"',
        arguments = [args],
        mnemonic = "AwkToSource",
        progress_message = "Generating %s" % ctx.attr.out_name,
    )
    return [DefaultInfo(files = depset([out]))]

awk_to_source = rule(
    implementation = _awk_to_source_impl,
    doc = "Pipes a file through an awk script to produce a C source file.",
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "script": attr.label(allow_single_file = True, mandatory = True),
        "out_name": attr.string(mandatory = True),
        "out_dir": attr.string(mandatory = True),
        "_awk": _AWK,
    },
)

def _gen_header_impl(ctx):
    out = ctx.actions.declare_file("{}/{}".format(ctx.attr.out_dir, ctx.attr.out_name))
    tool = ctx.executable.tool

    args = ctx.actions.args()
    args.add(tool)
    args.add(out)

    ctx.actions.run_shell(
        tools = [tool],
        outputs = [out],
        command = '"$1" > "$2"',
        arguments = [args],
        mnemonic = "GenHeader",
        progress_message = "Generating %s" % ctx.attr.out_name,
    )
    return [DefaultInfo(files = depset([out]))]

gen_header = rule(
    implementation = _gen_header_impl,
    doc = "Captures a host tool's stdout into a generated header.",
    attrs = {
        "tool": attr.label(executable = True, cfg = "exec", mandatory = True),
        "out_name": attr.string(mandatory = True),
        "out_dir": attr.string(mandatory = True),
    },
)

def _copy_file_impl(ctx):
    out = ctx.actions.declare_file("{}/{}".format(ctx.attr.out_dir, ctx.attr.out_name))
    ctx.actions.expand_template(
        template = ctx.file.src,
        output = out,
        substitutions = {},
    )
    return [DefaultInfo(files = depset([out]))]

copy_file = rule(
    implementation = _copy_file_impl,
    doc = "Renames a file into the generated tree; blkid.h.in and uuid.h.in " +
          "are installed by a plain cp upstream.",
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "out_name": attr.string(mandatory = True),
        "out_dir": attr.string(mandatory = True),
    },
)
