#!/usr/bin/env python3

################################################################################
# MIT License
#
# Copyright (c) 2022, 2023 STMicroelectronics.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
################################################################################
#
# Author: Torbjörn SVENSSON <torbjorn.svensson@foss.st.com>
#
################################################################################

import sys
import re
import difflib
import subprocess
import pathlib
import os
import shutil
from optparse import OptionParser
try:
  import magic
except:
  print("You need to install python-magic")
  sys.exit(1)

DEBUG = 0
CFLAGS = "-g3 -Og -std=gnu11 -Wall -Werror -pedantic".split()
LIBNAME = "longpath-win32"

def debug(s):
    if DEBUG:
        print(s, file=stderr)

def abort(s):
    print(s)
    sys.exit(1)

def run_command(args):
    def quote_if_needed(s):
        if " " in s:
            return f"\"{s}\""
        return s

    print(" ".join([quote_if_needed(str(s)) for s in args]))

    # Force flush to allow subprocess to inherit stdout and stderr in a good state
    sys.stdout.flush()
    sys.stderr.flush()

    if subprocess.run(args).returncode != 0:
        sys.exit(1)

def list_functions(src, prefix, triplet):
    pattern = re.compile(r"^(" + prefix + r"[^ \(]+)")
    funcs = []
    include_path = pathlib.Path(__file__).parent.resolve() / "include"
    for path in src.rglob("*.c"):
        debug(f"path: {path}")
        output = subprocess.run([get_prefixed_tool(triplet, "gcc"), "-E", "-I", str(include_path), str(path)], check=True, encoding="ascii", stdout=subprocess.PIPE).stdout
        for line in output.splitlines():
            m = pattern.match(line)
            if m:
                funcs.append(m.group(1))
    return funcs

def get_wrapped_apis(src, isDll, triplet):
    prefix = "__wrap_"
    apis = [api[len(prefix):] for api in list_functions(src, prefix, triplet)]

    if isDll:
        # Wrap main in order to correctly handled paths on command line
        # DLL files does not contain any normal main functions, so do not try to wrap it
        apis.remove("main")

    return apis

def list_internal_functions(src, triplet):
    return list_functions(src, "internal_", triplet)

def get_prefixed_tool(triplet, tool):
    if triplet:
        return triplet + "-" + tool
    return tool

def get_mingw_include_path(triplet):
    result = subprocess.run([get_prefixed_tool(triplet, "gcc"), "-xc", os.devnull, "-E", "-Wp,-v"], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, encoding="utf-8")
    for path in result.stderr.splitlines():
        if path.startswith(" "):
            path = pathlib.Path(path.strip())
            if (path / "dirent.h").is_file():
                return path

def find_on_path(triplet):
    known_tools = set()
    pattern = re.compile(re.escape(get_prefixed_tool(triplet, "")) + r"(c\+\+|cpp|gcc|g\+\+)(-\d+)?(-(posix|win32))?(\.exe)?$")
    for p in os.environ["PATH"].split(os.pathsep):
        for toolpath in pathlib.Path(p).glob(f"{triplet}*"):
            if pattern.match(toolpath.name):
                if toolpath.name not in known_tools:
                    yield toolpath
                known_tools.add(toolpath.name)

def generate(apis, triplet, output):
    mingw_path = get_mingw_include_path(triplet)
    debug("mingw_path: {mingw_path}")
    if not mingw_path:
        abort("Failed to locate include path for mingw compiler")

    include_path = output.absolute() / "include"
    bin_path = output.absolute() / "bin"
    gcc_path = output.absolute() / "gcc"
    objs_path = output.absolute() / "objs"
    root_path = pathlib.Path(__file__).parent.resolve()

    # Generate bin files
    bin_path.mkdir(parents=True, exist_ok=True)
    for path in find_on_path(triplet):
        debug(f"path {path} matches")
        with open(bin_path / path.name, "w", encoding="utf-8") as f:
            f.write(f"""#!/usr/bin/env python3
import os
import sys

args = ["{path}", "-isystem", "{include_path}", *sys.argv[1:]]

def append_if_missing(opt):
  if opt not in args:
    args.append(opt)

out = "{output.parent.absolute() / 'unknown'}"
if "-o" in args:
  out = args[args.index("-o") + 1]

if "-c" not in args and os.environ.get("LP_ENABLE_WRAP_AUTODETECT_LINK_FLAGS"):
  if any(filter(lambda x: x.startswith("-Wl,-e"), args)):
    # Uses a custom entry point, do not include __wrap_main!
    append_if_missing("@{gcc_path / 'dll.inputs'}")
  elif out.endswith(".exe"):
    append_if_missing("@{gcc_path / 'exe.inputs'}")
  elif out.endswith(".dll"):
    append_if_missing("@{gcc_path / 'dll.inputs'}")

  append_if_missing("-static-libgcc")
  append_if_missing("-static-libstdc++")

if os.environ.get("LP_ENABLE_WRAP_DEBUG"):
  import pprint
  with open("%s.lpcommand-%d.log" % (out, os.getpid()), "w") as f:
    pprint.PrettyPrinter(stream=f).pprint(args)

os.execvp(args[0], args)
""")
        (bin_path / path.name).chmod(0o755)

    # Generate include files
    diff = []
    for path in mingw_path.rglob("*.h"):
        debug(f"handling {path}")
        src_lines = []
        try:
            with open(path, "r", encoding="utf-8") as f:
                src_lines = f.readlines()
        except UnicodeDecodeError:
            with open(path, "r", encoding="latin1") as f:
                src_lines = f.readlines()

        src_lines = "".join(src_lines)
        tgt_lines = re.sub(
            r"([\r\n]\s*)(?:_CRTIMP|_SECIMP|WINBASEAPI)\s(.*\s(?:{})\s*\()".format("|".join(apis)),
            r"\1\2",
            src_lines)

        if src_lines is not tgt_lines:
            relpath = path.relative_to(mingw_path)
            debug(f"relpath: {relpath}")

            target = include_path / relpath
            target.parent.mkdir(parents=True, exist_ok=True)

            with open(target, "w", encoding="utf-8") as f:
                f.write(tgt_lines.replace("\r", ""))

            debug("patched {target}")
            diff.append(difflib.unified_diff(src_lines.splitlines(True), tgt_lines.splitlines(True), fromfile=str(path.resolve()), tofile=str(target.resolve())))

    with open(output.absolute() / "headers.patch", "w") as f:
        for d in diff:
            f.writelines(d)

    # Build the library
    objs_path.mkdir(parents=True, exist_ok=True)

    shutil.copytree(root_path / "include" / "stmicroelectronics", include_path / "stmicroelectronics")
    objs = []
    for cfile in sorted((root_path / "src").glob("*.c")):
        name = f"{cfile.name}.o"
        objs.append(objs_path / name)
        run_command([bin_path / get_prefixed_tool(triplet, "gcc"), "-c", *CFLAGS, cfile, "-o", objs[-1]])


    # Generate gcc input files
    gcc_path.mkdir(parents=True, exist_ok=True)
    for name in ["exe.inputs", "dll.inputs"]:
        with open(gcc_path / name, "w", encoding="utf-8") as f:
            isExe = name.startswith("exe")
            for api in apis:
                if isExe or api not in ("main", "_main", "__main"):
                    f.write(f"-Wl,--wrap={api}\n")
            for obj in objs:
                if isExe or obj.name != "main-win32.c.o":
                    f.write(f"{obj}\n")


def list_exe(path):
    PE_PATTERN = re.compile(r"PE32\+? ")
    for path in sorted(path.rglob("*")):
        # Only include PE files
        if not path.is_file() or not PE_PATTERN.match(magic.from_file(str(path))):
            continue

        yield path


def strip_exe(triplet, path):
    for path in sorted(list_exe(path)):
        command = [get_prefixed_tool(triplet, "strip"), str(path).replace("/cygdrive/c", "")]
        run_command(command)


def validate_wrapped_exe(apis, helpers, triplet, path):
    LAST_FUNC_PATTERN = re.compile(r"[0-9a-fA-F]+\s+<(.*)>:")
    CALL_PATTERN = re.compile(r"\s*[0-9a-fA-F]+:.*(?:call|jmp)q?.*<([a-zA-Z0-9_]+)>")

    class FuncState:
        def __init__(self, name):
            self.name = name
            self.call_lines = []

        def append(self, line):
            self.call_lines.append(line)

        def print(self):
            if not self.is_valid():
                print(self.name)
                for line in self.call_lines:
                    print(line)

        def is_valid(self):
            return not self.call_lines

    is_valid = True
    for path in sorted(list_exe(path)):
        print(f"Checking {path}")
        model = list()
        command = [get_prefixed_tool(triplet, "objdump"), "-d", str(path).replace("/cygdrive/c", "")]
        debug(f"Running command: {command}\n")
        result = subprocess.run(command, stdout=subprocess.PIPE, encoding="utf-8")
        for line in result.stdout.splitlines():
            m = LAST_FUNC_PATTERN.match(line)
            if m:
                model.append(FuncState(m.group(1)))
                continue

            m = CALL_PATTERN.match(line)
            if m:
                func = model[-1]
                callie = m.group(1)
                if "__imp_" + func.name == callie:
                    # Function called _wopen is allowed to use the __imp__wopen
                    # symbol (example)
                    continue

                if func.name.startswith("__wrap_"):
                    # The __wrap_* functions are allowed to use the __imp_* symbols
                    continue

                if func.name in helpers:
                    # The __internal_* functions are allowed to use the __imp_* symbols
                    continue

                if func.name in apis:
                    # Current function is one of the API functions.
                    continue

                if callie.replace("__imp_", "") not in apis:
                    # Not one of the interresting functions
                    continue

                func.append(line)

        for x in model:
            x.print()

        if any(not x.is_valid() for x in model):
            is_valid = False
            print()

    if not is_valid:
        sys.exit(1)


if __name__ == "__main__":
    parser = OptionParser("%prog [options]", version="%prog 1.0")
    parser.add_option("--debug", dest="debug", action="store_true", default=False)
    parser.add_option("--triplet", dest="triplet", default="x86_64-w64-mingw32")

    parser.add_option("--generate", dest="generate")
    parser.add_option("--strip", dest="strip")
    parser.add_option("--ldflags", dest="ldflags", action="store_true", default=False)
    parser.add_option("--dll", dest="dll", action="store_true", default=False)
    parser.add_option("--validate", dest="validate")
    parser.add_option("--list", dest="list", action="store_true", default=False)

    (options, args) = parser.parse_args()

    if options.dll and not options.ldflags:
        abort("Can't use dll argument without ldflags.")

    DEBUG = options.debug

    src = pathlib.Path(__file__).parent.resolve() / "src"
    apis = get_wrapped_apis(src, options.dll, options.triplet)
    debug("apis: {apis}")
    if not apis:
        abort("Failed to list wrapped apis")

    if options.list:
        print("Wrapped methods:")
        for api in sorted(apis, key=lambda x: x[1:] if x[0] == "_" else x):
            print(api)
    elif options.generate:
        generate(apis, options.triplet, pathlib.Path(options.generate))
    elif options.ldflags:
        flags = ",".join([f"--wrap={x}" for x in apis])
        print(f"-Wl,{flags}")
    elif options.validate:
        helpers = list_internal_functions(src, options.triplet)
        validate_wrapped_exe(apis, helpers, options.triplet, pathlib.Path(options.validate))
    elif options.strip:
        strip_exe(options.triplet, pathlib.Path(options.strip))
    else:
        parser.error("invalid option")
        sys.exit(1)

    sys.exit(0)
