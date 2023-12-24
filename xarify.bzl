MAKE_XAR_WRAPPER = "//tools:make_xar_wrapper"

def _gen_exec_wrapper(main_cmd):
    return """#!/bin/bash

dir=$(dirname $0)
name=$(basename "$1")
# XAR is passing the name of "xar executable" as the first arguement, we skip it
shift
exec "$dir"/{cmd} "$@" """.format(cmd = main_cmd.basename)

def _xar_binary_impl(ctx):
    # We will use the python_zil_file that py_binary _can_ generate_
    python_zip = ctx.attr.main[OutputGroupInfo]["python_zip_file"].to_list()[0]
    main_file = ctx.attr.main.files_to_run.executable

    # Regular (source and generated) files: inputs

    tgt_exec_wrapper = ctx.actions.declare_file("{}_wrapper".format(main_file.basename))
    ctx.actions.write(
        output = tgt_exec_wrapper,
        content = _gen_exec_wrapper(main_file),
        is_executable = True,
    )

    include_make_xar = False
    if ctx.executable.make_xar == None:
        make_xar_name = "make_xar"
    else:
        include_make_xar = True
        make_xar_name = ctx.executable.make_xar.path

    # Inputs to the action, but don't actually get stored in the .xar file
    extra_inputs = [
        main_file,
        tgt_exec_wrapper,
    ]
    if include_make_xar:
      extra_inputs.append(ctx.executable.make_xar)

    # Assemble command line for .xar compiler
    args = [
        make_xar_name,
        "0",
        python_zip.path,
        main_file.path,
        tgt_exec_wrapper.path,
        ctx.outputs.executable.path,
    ]

    all_inputs = depset(transitive = [d for d in [depset(extra_inputs), ctx.attr.main[OutputGroupInfo]["python_zip_file"]]])
    ctx.actions.run(
        inputs = all_inputs,
        outputs = [ctx.outputs.executable],
        progress_message = "Building xar file %s" % ctx.label,
        executable = ctx.executable._make_xar_wrapper,
        arguments = args,
        use_default_shell_env = True,
        mnemonic = "MakeXar",
    )

    # .xar file itself has no runfiles and no providers
    return []

xar_binary = rule(
    implementation = _xar_binary_impl,
    attrs = {
        "main": attr.label(
            mandatory = True,
        ),
        "make_xar": attr.label(
            executable = True,
            cfg = "exec",
        ),
        "_make_xar_wrapper": attr.label(
          default = Label(MAKE_XAR_WRAPPER),
          executable = True,
          cfg = "exec",
        ),

    },
    executable = True,
)
