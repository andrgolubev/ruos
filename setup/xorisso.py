#!/usr/bin/env python

from __future__ import print_function
import os
import sys
import subprocess
import shutil


def install_xorisso(work_dir, version='1.4.6'):
    """Install xorisso to /usr/ folder"""
    if os.path.isdir(work_dir):
        shutil.rmtree(work_dir)
    os.mkdir(work_dir)
    commands = """
    wget https://www.gnu.org/software/xorriso/xorriso-{version}.tar.gz
    tar -xzf xorriso-{version}.tar.gz
    cd xorriso-{version}/
    """.format(version=version)
    # ./configure --prefix=/usr
    # make
    # sudo make install
    for cmd_line in commands.splitlines():
        cmd_line = cmd_line.strip()
        subprocess.check_call(cmd_line, shell=True, cwd=work_dir)
    # shutil.rmtree(work_dir)
    return version


# TODO: automate xorriso install
def main():
    """Main entry point"""
    work_dir = os.path.join(os.environ['HOME'], '_xorisso')
    ver = None
    if len(sys.argv) > 1:
        work_dir = sys.argv[1]
    try:
        ver = install_xorisso(work_dir)
    except subprocess.CalledProcessError as e:
        print('Failed:', e)
        return 1

    if ver:
        package = 'xorriso-{version}'.format(version=ver)
        print('Successfully downloaded', package)
        print('Further steps are: (work dir is {cwd})'.format(
            cwd=os.path.join(work_dir, package)))
        print('\t./configure --prefix=/usr')
        print('\tmake')
        print('\tsudo make install')
    return 0


if __name__ == "__main__":
    sys.exit(main())
