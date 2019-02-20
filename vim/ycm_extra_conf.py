from distutils.sysconfig import get_python_inc
import platform
import os.path as p
import subprocess
import ycm_core

DIR_OF_THIS_SCRIPT = p.abspath(p.dirname(__file__))
DIR_OF_THIRD_PARTY = p.join(DIR_OF_THIS_SCRIPT, 'third_party')
SOURCE_EXTENSIONS = ['.cpp', '.cxx', '.cc', '.c', '.m', '.mm']

flags = [
    '-Wall',
    '-Wextra',
    '-Werror',
    '-Wno-long-long',
    '-Wno-variadic-macros',
    '-fexceptions',
    '-DNDEBUG',
    '-x',
    'c++',
    '-isystem',
    'cpp/pybind11',
    '-isystem',
    'cpp/BoostParts',
    '-isystem',
    get_python_inc(),
    '-isystem',
    'cpp/llvm/include',
    '-isystem',
    'cpp/llvm/tools/clang/include',
    '-I',
    'cpp/ycm',
    '-I',
    'cpp/ycm/ClangCompleter',
    '-isystem',
    'cpp/ycm/tests/gmock/gtest',
    '-isystem',
    'cpp/ycm/tests/gmock/gtest/include',
    '-isystem',
    'cpp/ycm/tests/gmock',
    '-isystem',
    'cpp/ycm/tests/gmock/include',
    '-isystem',
    'cpp/ycm/benchmarks/benchmark/include',
]

# Clang automatically sets the '-std=' flag to 'c++14' for MSVC 2015 or later,
# which is required for compiling the standard library, and to 'c++11' for
# older versions.
if platform.system() != 'Windows':
    flags.append('-std=c++11')


# Set this to the absolute path to the folder (NOT the file!) containing the
# compile_commands.json file to use that instead of 'flags'. See here for
# more details: http://clang.llvm.org/docs/JSONCompilationDatabase.html
#
# You can get CMake to generate this file for you by adding:
#   set( CMAKE_EXPORT_COMPILE_COMMANDS 1 )
# to your CMakeLists.txt file.
#
# Most projects will NOT need to set this to anything; you can just change the
# 'flags' list of compilation flags. Notice that YCM itself uses that approach.
compilation_database_folder = ''

if p.exists(compilation_database_folder):
    database = ycm_core.CompilationDatabase(compilation_database_folder)
else:
    database = None


def IsHeaderFile(filename):
    extension = p.splitext(filename)[1]
    return extension in ['.h', '.hxx', '.hpp', '.hh']


def FindCorrespondingSourceFile(filename):
    if IsHeaderFile(filename):
        basename = p.splitext(filename)[0]
        for extension in SOURCE_EXTENSIONS:
            replacement_file = basename + extension
            if p.exists(replacement_file):
                return replacement_file
    return filename


def PathToPythonUsedDuringBuild():
    try:
        filepath = p.join(DIR_OF_THIS_SCRIPT, 'PYTHON_USED_DURING_BUILDING')
        with open(filepath) as f:
            return f.read().strip()
    # We need to check for IOError for Python 2 and OSError for Python 3.
    except (IOError, OSError):
        return None


def Settings(**kwargs):
    language = kwargs['language']

    if language == 'cfamily':
        # If the file is a header, try to find the corresponding source file
        # and retrieve its flags from the compilation database if using one.
        # This is  necessary since compilation databases don't have entries for
        # header files. In addition, use this source file as the translation
        # unit. This makes it possible to jump from a declaration in the header
        # file to its definition in the corresponding source file.
        filename = FindCorrespondingSourceFile(kwargs['filename'])

        if not database:
            return {
                'flags': flags,
                'include_paths_relative_to_dir': DIR_OF_THIS_SCRIPT,
                'override_filename': filename
            }

        compilation_info = database.GetCompilationInfoForFile(filename)
        if not compilation_info.compiler_flags_:
            return {}

        # Bear in mind that compilation_info.compiler_flags_ does NOT return a
        # python list, but a "list-like" StringVec object.
        final_flags = list(compilation_info.compiler_flags_)

        return {
            'flags': final_flags,
            'include_paths_relative_to_dir':
                compilation_info.compiler_working_dir_,
            'override_filename': filename
        }

    if language == 'python':
        return {
            'interpreter_path': PathToPythonUsedDuringBuild()
        }

    return {}


def GetStandardLibraryIndexInSysPath(sys_path):
    for index, path in enumerate(sys_path):
        if p.isfile(p.join(path, 'os.py')):
            return index
    raise RuntimeError('Could not find standard library path in Python path.')


def PythonSysPath(**kwargs):
    sys_path = kwargs['sys_path']

    interpreter_path = kwargs['interpreter_path']
    major_version = subprocess.check_output([
        interpreter_path, '-c', 'import sys; print( sys.version_info[ 0 ] )']
    ).rstrip().decode('utf8')

    sys_path.insert(GetStandardLibraryIndexInSysPath(sys_path) + 1,
                    p.join(DIR_OF_THIRD_PARTY, 'python-future', 'src'))
    sys_path[0:0] = [p.join(DIR_OF_THIS_SCRIPT),
                     p.join(DIR_OF_THIRD_PARTY, 'bottle'),
                     p.join(DIR_OF_THIRD_PARTY, 'cregex',
                            'regex_{}'.format(major_version)),
                     p.join(DIR_OF_THIRD_PARTY, 'frozendict'),
                     p.join(DIR_OF_THIRD_PARTY, 'jedi'),
                     p.join(DIR_OF_THIRD_PARTY, 'parso'),
                     p.join(DIR_OF_THIRD_PARTY, 'requests'),
                     p.join(DIR_OF_THIRD_PARTY, 'waitress')]

    return sys_path
