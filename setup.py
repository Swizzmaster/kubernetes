import re
import os
from glob import glob
from setuptools import setup, find_packages


def find_data_files(datadir):
    content = []
    for root, dirs, files in os.walk(datadir):
        content.append((root, [os.path.join(root, f) for f in files]))
    return content

data_files = find_data_files("configuration")

# declare your scripts:
# scripts in bin/ with a shebang containing python will be
# recognized automatically
scripts = []
for fname in glob('bin/*'):
    with open(fname, 'r') as fh:
        if re.search(r'^#!.*python', fh.readline()):
            scripts.append(fname)

setup(name="ekspatch",
    version="1.0",

    # declare your packages
    packages=find_packages(where="src", exclude=("test",)),
    package_dir={"": "src"},

    entry_points="""\
    [console_scripts]
    ekspatch = ekspatch.cli:main
    """,

    # declare your scripts
    #scripts=scripts,

    # include data files
    data_files=data_files,

    # set up the shebang
    options={
        # make sure the right shebang is set for the scripts - use the environment default Python
        'build_scripts': {
            #'executable': '/usr/bin/env python3',
            'executable': '/apollo/sbin/envroot "$ENVROOT/bin/python"',
        },
    },

    # build scripts with Python-default
    #root_script_sourco_version=True,
    root_script_source_version="default-only"

    # Use the pytest brazilpython runner. Provided by BrazilPython-Pytest-2.x
    #test_command='brazilpython_pytest',

    # Run static analysis and style checks for the test target:
    #test_flake8=True,

    # Use Sphinx for docs
    #doc_command='build_sphinx',
)
