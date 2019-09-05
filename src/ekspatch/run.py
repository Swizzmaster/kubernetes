import os
import shlex
from subprocess import PIPE, STDOUT, Popen
from contextlib import contextmanager

from loguru import logger


@contextmanager
def cd(newdir):
    prevdir = os.getcwd()
    os.chdir(os.path.expanduser(newdir))
    try:
        yield
    finally:
        os.chdir(prevdir)

class ProcessRunner:
    """Runs a process and logs its stderr based on debug setting"""

    def __init__(self):
        pass

    def execute_command(self, command, cwd=None):
        # if we got a string, split the command
        cmd = shlex.split(command) if type(command) == str else command
        cwd = cwd or os.getcwd()
        logger.debug("Executing: {}".format(" ".join(cmd)))
        popen = Popen(cmd, stdout=PIPE, stderr=STDOUT, universal_newlines=True)
        out = output_iter(popen.stdout)
        return_code = popen.wait()
        return return_code, out

def output_iter(stdout):
    for stdout_line in iter(stdout.readline, ""):
        yield stdout_line
    stdout.close()
