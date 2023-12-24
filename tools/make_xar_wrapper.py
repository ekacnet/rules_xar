#!/usr/bin/env python3

import os
import sys
import shutil
import zipfile
import pathlib
import re
import subprocess


def main():
    current = os.getcwd()
    make_xar_binary = sys.argv[1]
    if "/" in make_xar_binary:
        make_xar_binary = f"{current}/{make_xar_binary}"
    strip_python = sys.argv[2]
    zip_file = os.path.basename(sys.argv[3])
    zip_directory = os.path.dirname(sys.argv[3])

    main_file = os.path.basename(sys.argv[4])
    main_file_fullpath = sys.argv[4]
    wrapper = sys.argv[5]
    output = sys.argv[6]

    out_directory = f"{zip_directory}/out"

    os.mkdir(out_directory)
    shutil.move(wrapper, out_directory)

    if output[0] != "/":
        output = f"{current}/{output}"

    dest_main = f"{out_directory}/{main_file}"
    python_binary = None
    with open(main_file_fullpath, "r") as ref_main:
        with open(dest_main, "w") as new:
            for line in ref_main.readlines():
                m = re.match(r"^PYTHON_BINARY = '(.*)'$", line)
                if m:
                    python_binary = m.group(1)
                m = re.match(r"(.*)args = sys.argv.*", line)
                if m:
                    new.write(f"{m.group(1)}args = sys.argv[2:]\n")
                else:
                    new.write(f"{line}")

    # Make the new main binary executable
    os.chmod(dest_main, 0o755)
    if python_binary is None:
        print(f"Can't parse {main_file} and find a python_binary", file=sys.stderr)
        sys.exit(1)

    with zipfile.ZipFile(f"{zip_directory}/{zip_file}", "r") as zip_ref:
        zip_ref.extractall(out_directory)

    os.chdir(out_directory)
    # Find the "python binary" in runfiles and make it executable
    os.chmod(f"runfiles/{python_binary}", 0o755)
    shutil.move("runfiles", f"{main_file}.runfiles")

    for f in ["__main__.py", "__init__.py"]:
        pathlib.Path(f).unlink()

    args = [
        make_xar_binary,
        "--raw",
        ".",
        "--raw-executable",
        f"{os.path.basename(wrapper)}",
        "--output",
        output,
    ]
    subprocess.run(args, capture_output=True)


main()
