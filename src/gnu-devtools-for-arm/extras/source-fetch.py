#!/usr/bin/env python3

try:
    import configparser
except ImportError:
    import configparser as ConfigParser
import argparse
import logging
import os
import io
import sys
import subprocess
import shutil
import tempfile

def remove_force(path):
    try:
        os.remove(path)
    except OSError:
        pass


class TemporaryDirectory:
    def __enter__(self):
        self.tempdir = tempfile.mkdtemp()
        return self.tempdir

    def __exit__(self, type, value, traceback):
        shutil.rmtree(self.tempdir)


class TemporaryFile:
    def __init__(self):
        self.name = named_temporary()

    def __enter__(self):
        return self.name

    def __exit__(self, type, value, traceback):
        remove_force(self.name)


def named_temporary():
    fd = tempfile.NamedTemporaryFile(delete=False)
    fd.close()
    return fd.name

def wget(url, path):
    tmp = path + ".t"
    rm(tmp, force=True)
    shell(["wget", "-O", tmp, url])
    mv(tmp, path)


def fetch_raw(url, path, netrcfile=None):
    wget(url, path)

def fetch_url(url, path, netrcfile=None):
    if not os.path.exists(path):
        dir_name = os.path.dirname(path)
        if dir_name:
            mkdir(dir_name, parents=True)
        fetch_raw(url, path, netrcfile=netrcfile)

class ShellException(Exception):
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return str(self.value)


def cat(path, fd=sys.stdout):
    with open(path, "r") as fd_in:
        for line in fd_in:
            fd.write(line)


def ls(path):
    return os.listdir(path)


def mkdir(path, parents=False):
    if parents:
        if not os.path.exists(path):
            os.makedirs(path)
    else:
        os.mkdir(path)


def mv(src, dst):
    shutil.move(src, dst)


def rm(path, recursive=False, force=False):
    if force and not os.path.lexists(path):
        return
    if os.path.isdir(path) and not os.path.islink(path):
        if recursive:
            for f in ls(path):
                rm(os.path.join(path, f), recursive=True, force=force)
        os.rmdir(path)
    else:
        os.remove(path)


def rmdir(path):
    os.rmdir(path)


def shell(args, stdout_fd=None, stdout=None, cwd=None):
    if stdout_fd:
        inferior = subprocess.Popen(args=args, stdout=stdout_fd, cwd=cwd)
        return_code = inferior.wait()
    elif stdout:
        with open(stdout, "w") as stdout_fd:
            inferior = subprocess.Popen(args=args, stdout=stdout_fd, cwd=cwd)
            return_code = inferior.wait()
    else:
        inferior = subprocess.Popen(args=args, cwd=cwd)
        return_code = inferior.wait()
    if return_code != 0:
        raise ShellException(return_code)


def touch(fname, times=None):
    with open(fname, "a"):
        os.utime(fname, times)


def readfile(path):
    with open(path, "r") as fd:
        contents = fd.read()
    return contents

def patch(dir_name, patchfile):
    shell(["patch", "-d", dir_name, "-i", patchfile])

def probe_tar_strip_arg():
    try:
        shell(
            ["tar", "--strip-components=1", "--help", "-f", "/dev/null"],
            stdout="/dev/null",
        )
    except ShellException:
        tar_strip_arg = "--strip-path"
    else:
        tar_strip_arg = "--strip-components"
    return tar_strip_arg


def tar_extract(tarball, strip=0, directory=None):
    """Extract the specified tarball."""
    args = ["tar", "x"]
    if directory:
        args = args + ["-C", directory]
    if strip:
        strip_arg = probe_tar_strip_arg()
        args = args + [strip_arg, str(strip)]
    args = args + ["-f", tarball]
    shell(args)


def tar(tarball, what, directory=None):
    args = ["tar", "c"]
    if directory:
        args = args + ["-C", directory]
    args = args + ["-f", tarball]
    args = args + [what]
    shell(args)


def verbose_write(msg):
    sys.stdout.write(msg)


def tarball_acquire_explode_patch(url, srcpath, downloaddir, seriesurl=None, verbose=False):
    bundle = os.path.basename(url)

    if os.path.isdir(srcpath):
        if verbose:
            verbose_write("Found %s\n" % srcpath)
    else:
        bundlepath = os.path.join(downloaddir, bundle)
        if not os.path.isfile(bundlepath):
            if verbose:
                verbose_write("Fetching %s\n" % url)
            fetch_url(url, bundlepath)

        packagedir = srcpath + ".tmp"

        rm(srcpath, recursive=True, force=True)
        rm(packagedir, recursive=True, force=True)

        mkdir(packagedir, parents=True)

        if verbose:
            verbose_write("Expanding %s\n" % url)
        tar_extract(bundlepath, directory=packagedir, strip=1)
        if seriesurl:
            baseurl = os.path.dirname(seriesurl)

            if not os.path.exists(os.path.join(packagedir, "=series")):
                if verbose:
                    verbose_write("Fetching series file\n")
                fetch_url(seriesurl, os.path.join(packagedir, "=series"))
                contents = readfile(os.path.join(packagedir, "=series"))
                print(contents)
                for line in contents.splitlines():
                    line = line.strip()
                    if line != "":
                        patchline = line
                        if verbose:
                            verbose_write("Fetching patch %s\n" % patchline)
                        tmpdir = tempfile.mkdtemp(prefix="bld")
                        try:
                            tmp = os.path.join(tmpdir, "patch.diff")
                            fetch_url(os.path.join(baseurl, patchline), tmp)
                            if verbose:
                                verbose_write("Applying patch %s\n" % patchline)
                            patch(packagedir, tmp)
                        finally:
                            rm(tmpdir, force=True, recursive=True)
        mv(packagedir, srcpath)


def archive(url, srcpath, downloaddir, seriesurl=None, verbose=False):
    bundle = os.path.basename(url)

    bundlepath = os.path.join(downloaddir, bundle)
    if not os.path.isfile(bundlepath):
        if verbose:
            verbose_write("Fetching %s\n" % url)
    fetch_url(url, bundlepath + ".t")

    if seriesurl:
        if verbose:
            verbose_write("Fetching series file\n")
        fetch_url(seriesurl, bundle + ".series")
        patches = parse_series_file(bundle + ".series")

        if patches != []:
            rm(packagedir, recursive=True, force=True)
            tmpdir = tempfile.mkdtemp(prefix="bld")
            try:
                packagedir = os.path.join(tmpdir, bundle)
                mkdir(packagedir)
                tar_extract(bundlepath, directory=packagedir, strip=1)
                for patch in patches:
                    if verbose:
                        verbose_write("Fetching patch %s\n" % patch)
                        tmp = os.path.join(tmpdir, "patch.diff")
                        fetch_url(os.path.join(baseurl, patch), tmp)
                        if verbose:
                            verbose_write("Applying patch %s\n" % patch)
                        patch(packagedir, tmp)
                tar(bundlepath, bundle, tmpdir)
            finally:
                rm(tmpdir, force=True, recursive=True)
            return
    mv(bundlepath + ".t", bundlepath)

def parse_series_file(fname):
    contents = readfile(bundle + ".series")
    contents.splitlines()
    patches = []
    for line in contents.splitlines():
        line = line.strip()
        if line != "":
            patches.append(line)
    return patches


class GitException(Exception):
    def __init__(self, uri, value):
        self.uri = uri
        self.value = value

    def __str__(self):
        return self.uri + "\n" + self.value


class GitIface(object):
    def __init__(self, url, path=None, logger=None):
        self.url = url
        self._path = path
        self._logger = logger or logging.getLogger(__name__)

    def _archive_fd(self, what, prefix, fd):
        command = [
            "git",
            "archive",
            "--prefix",
            prefix + "/",
            "--format",
            "tar",
            "--remote",
            self.url,
            what,
        ]
        self._logger.debug(" ".join(command))
        child = subprocess.Popen(command, cwd=self._path, stdout=fd, stderr=subprocess.PIPE)
        comms = child.communicate()
        if child.wait() != 0:
            raise GitException(self.url, comms[1].decode())

    def _archive_via_clone_fd(self, what, prefix, fd):
        with TemporaryDirectory() as tmp:
            dst = os.path.join(tmp, prefix)

            command = ["git", "clone", "--mirror", self.url, dst]
            self._logger.debug(" ".join(command))

            child = subprocess.Popen(command, cwd=self._path, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            comms = child.communicate()
            if child.wait() != 0:
                raise GitException(self.url, comms[1].decode())

            command = [
                "git",
                "archive",
                "--prefix",
                prefix + "/",
                "--format",
                "tar",
                what,
            ]
            self._logger.debug(" ".join(command))
            child = subprocess.Popen(command, cwd=dst, stdout=fd, stderr=subprocess.PIPE)
            comms = child.communicate()
            if child.wait() != 0:
                raise GitException(self.url, comms[1].decode())

    def _correct_tar_format(self, fname, fd):
        """To fix the tar format issue"""
        if not fname:
            raise RuntimeError("Undefined argument")

        filename = os.path.basename(fname)
        src_dir = os.path.dirname(fname)

        command = ["tar", "-xvf", filename]
        self._logger.debug(" ".join(command))
        child = subprocess.Popen(command, cwd=src_dir, stdout=fd, stderr=subprocess.PIPE)
        comms = child.communicate()
        if child.wait() != 0:
            self._logger.error("Unable to extract tar")
            raise Exception(comms[1].decode())

        command = ["tar", "-cvf", filename, os.path.splitext(filename)[0] + "/"]
        self._logger.debug(" ".join(command))
        child = subprocess.Popen(command, cwd=src_dir, stdout=fd, stderr=subprocess.PIPE)
        comms = child.communicate()
        if child.wait() != 0:
            self._logger.error("Unable to create tar")
            raise Exception(comms[1].decode())

        command = ["rm", "-rf", os.path.splitext(filename)[0]]
        self._logger.debug(" ".join(command))
        child = subprocess.Popen(command, cwd=src_dir, stdout=fd, stderr=subprocess.PIPE)
        comms = child.communicate()
        if child.wait() != 0:
            self._logger.error("Unable to delete dir")
            raise Exception(comms[1].decode())

    def archive_fd(self, what, prefix, fd, fname=None):
        try:
            self._archive_fd(what, prefix, fd)
            self._correct_tar_format(fname, fd)
        except GitException:
            self._archive_via_clone_fd(what, prefix, fd)

    def archive(self, what, prefix, fname):
        try:
            with open(fname, "wb") as fd:
                self.archive_fd(what, prefix, fd, fname)
        except:
            rm(fname, force=True)
            raise

    def current_branch(self):
        # Return the name of the current branch.
        return self.run_git_cmd(["rev-parse", "--abbrev-ref", "HEAD"]).strip()

    def branch(self, remote, local):
        command = ["git", "branch", "--track", local, remote]
        self._logger.debug(" ".join(command))
        child = subprocess.Popen(command, cwd=self._path, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        comms = child.communicate()
        if child.wait() != 0:
            raise GitException(self.url, comms[1].decode())

    def add_remote(self):
        command = ["git", "-C", self._path, "remote", "add", "origin"]
        command.append(self.url)
        child = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        comms = child.communicate()
        if child.wait() != 0:
            raise GitException(self.url, comms[1].decode())

    def checkout(self, version, quiet=False):
        command = ["git", "checkout"]
        if quiet:
            command.append("-q")
        command.append(version)
        self._logger.debug(" ".join(command))
        child = subprocess.Popen(command, cwd=self._path, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        comms = child.communicate()
        if child.wait() != 0:
            raise GitException(self.url, comms[1].decode())

    def fetch(self, shallow=False, remote=None, quiet=False, version=None):
        command = ["git", "fetch"]
        if quiet:
            command.append("-q")
        if remote is not None:
            command.append(remote)
        if shallow:
            command.append("--depth=1")
            command.append("origin")
            command.append(version)
        self._logger.debug(" ".join(command))
        child = subprocess.Popen(command, cwd=self._path, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        comms = child.communicate()
        if child.wait() != 0:
            raise GitException(self.url, comms[1].decode())

    def log_for_revision(self, revision):
        command = ["git", "log", "-n1", revision]
        self._logger.debug(" ".join(command))
        return subprocess.check_output(command, cwd=self._path)

    def reset(self, hard=False, quiet=False):
        command = ["git", "reset"]
        if hard:
            command.append("--hard")
        if quiet:
            command.append("-q")
        self._logger.debug(" ".join(command))
        child = subprocess.Popen(command, cwd=self._path, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        comms = child.communicate()
        if child.wait() != 0:
            raise GitException(self.url, comms[1].decode())

    def mv(self, path):
        mv(self._path, path)
        self._path = path

    def get_branches(self):
        command = ["git", "ls-remote", self.url]
        self._logger.debug(" ".join(command))
        child = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        comms = child.communicate()
        output = comms[0].decode()
        if child.wait() != 0:
            raise GitException(self.url, comms[1].decode())
        return [tuple(l.split()) for l in output.splitlines()]

    def get_revision(self, branch):
        def selector(xxx_todo_changeme):
            (revision, ref) = xxx_todo_changeme
            return ref == "refs/heads/" + branch or ref == "refs/remotes/" + branch or ref == "refs/" + branch

        branches = self.get_branches()
        branches = list(filter(selector, branches))
        if not branches:
            raise GitException(self.url, "url %s has no such branch %s" % (self.url, branch))
        revision, _ = branches[0]
        return revision

    def add_branch_fetch(self):
        command = [
            "git",
            "config",
            "--add",
            "remote.origin.fetch",
            "+refs/remotes/*:refs/remotes/origin/remotes/*",
        ]
        self._logger.debug(" ".join(command))
        child = subprocess.Popen(command, cwd=self._path, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        comms = child.communicate()
        if child.wait() != 0:
            raise GitException(self.url, comms[1].decode())

    def run_git_cmd(self, args):
        cmd = ["git"] + args
        self._logger.debug(" ".join(cmd))
        r = subprocess.run(cmd, cwd=self._path, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if r.returncode != 0:
          raise GitException(self.url, r.stderr.decode())
        return r.stdout.decode()

    def add_arm_vendor_remote(self):
        self.run_git_cmd(["config", "remote.vendors/ARM.url", self.url])
        self.run_git_cmd(["config",
          "remote.vendors/ARM.fetch",
          "+refs/vendors/ARM/*:refs/remotes/vendors/ARM/*"])

class Git(GitIface):
    def __init__(self, url, path, branch="master", logger=None):
        GitIface.__init__(self, url, path, logger)
        self._branch = branch

    @staticmethod
    def clone(url, path, mirror=False, logger=None):
        logger = logger or logging.getLogger(__name__)
        tmp = path + ".t"
        rm(tmp, force=True, recursive=True)
        command = ["git", "clone", "-n", "-q"]
        if mirror:
            command.append("--mirror")
        command.append(url)
        command.append(tmp)
        logger.debug(" ".join(command))
        child = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        comms = child.communicate()
        if child.wait() != 0:
            raise GitException(url, comms[1].decode())
        mv(tmp, path)
        git = Git(url, path)
        return git

    @staticmethod
    def git_init(url, path, logger=None):
        logger = logger or logging.getLogger(__name__)
        tmp = path + ".t"
        rm(tmp, force=True, recursive=True)
        command = ["git", "init"]
        command.append(tmp)
        logger.debug(" ".join(command))
        child = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        comms = child.communicate()
        if child.wait() != 0:
            raise GitException(comms[1].decode())
        mv(tmp, path)
        git = Git(url, path)
        return git

    def get_revision(self, branch=None):
        if branch is None:
            branch = self._branch
        return GitIface.get_revision(self, branch)

class SpcException(Exception):
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return self.value


class SpcItem(object):
    def __init__(self, name, logger=None, opt_arg=None):
        self._name = name
        self._logger = logger or logging.getLogger(__name__)
        self._opt_attributes = opt_arg or {}

    def __str__(self):
        return self._name

    def __eq__(self, other):
        """
        Compare two component specifications for equivalence.

        Two components specifications are only considered equivalent
        if they will always result in the same source tree for the
        component.  The names associated with the two components
        are never considered in the equivalence test.
        """
        return type(self) == type(other)

    def __ne__(self, other):
        return not self.__eq__(other)

    def _cmd_call(self, cmd):
        """Function calls process and returns return code
        @param cmd Command, list of attributes
        @return [Integer] Process return code
        """
        try:
            ret = subprocess.call(cmd)
            self._logger.debug("cmd='%s', ret=%d", " ".join(cmd), ret)
        except subprocess.CalledProcessError as e:
            raise SpcException(str(e))
        return ret

    def _cmd_check_output(self, cmd):
        """Function calls process and grabs stdout
        @param cmd Command, list of attributes
        @return Process output to stdout
        """
        output = str()
        try:
            self._logger.debug("cmd='%s'", " ".join(cmd))
            output = subprocess.check_output(cmd)
        except subprocess.CalledProcessError as e:
            raise SpcException(str(e))
        return output.decode().strip()

    def opt_attr(self):
        return self._opt_attributes


class SpcItemTarball(SpcItem):
    def __init__(self, name, url, series=None, logger=None, opt_arg=None):
        SpcItem.__init__(self, name, logger=logger, opt_arg=opt_arg)
        self._url = url
        self._series = series

    def __eq__(self, other):
        """
        Compare equal for two SpcItemTarball components.
        """

        if self.__class__ != other.__class__:
            return False

        if self._url != other._url:
            return False

        # Without pulling the series file and applying
        # the patches we cannot easily figure out if
        # a tar ball is equal.  For now we fail.
        if self._series is not None or other._series is not None:
            return False
        return True

    def __hash__(self):
        return hash(self._url)

    def archive_fd(self, fd):
        raise NotImplementedError

    def archive(self, output_dir):
        path = os.path.join(output_dir, self._name + ".tar")
        archive(self._url, path, ".", seriesurl=self._series)

    def checkout(self, srcdir, shallow=False, cache_path=None):
        path = os.path.join(srcdir, self._name)
        tarball_acquire_explode_patch(self._url, path, ".", seriesurl=self._series)


class SpcItemGitVersion(SpcItem):
    def __init__(self, name, url, version, logger=None, opt_arg=None):
        SpcItem.__init__(self, name, logger=logger, opt_arg=opt_arg)
        self._url = url
        self._version = version

    def __eq__(self, other):
        """
        Compare equal for two SpcItemGitVersion components.
        """

        if self.__class__ != other.__class__:
            return False

        if self._url != other._url:
            return False

        if self._version != other._version:
            return False

        return True

    def __hash__(self):
        return hash(self._url) + hash(self._version)

    def archive_fd(self, fd):
        repo = Git(self._url, None, logger=self._logger)
        repo.archive_fd(self._version, self._name, fd)

    def archive(self, output_dir):
        repo = Git(self._url, None, logger=self._logger)
        fname = os.path.join(output_dir, self._name + ".tar")
        repo.archive(self._version, self._name, fname)

    def checkout(self, srcdir, shallow=False, cache_path=None):
        path = os.path.join(srcdir, self._name)
        if not os.path.exists(path):
            if cache_path:
                cache_path = os.path.join(cache_path, self._name)
                if not os.path.exists(cache_path):
                    self._logger.debug("git clone %s %s (mirror)" % (self._url, self._name))
                    repo = Git.clone(self._url, cache_path, mirror=True, logger=self._logger)
                else:
                    repo = Git(self._url, cache_path, logger=self._logger)
                self._logger.debug("git fetch %s (mirror)" % self._name)
                repo.fetch()
            rm(path + ".tmp", force=True, recursive=True)
            url = self._url
            if cache_path:
                url = cache_path
            if shallow:
                self._logger.debug("git init")
                repo = Git.git_init(url, path, logger=self._logger)
                self._logger.debug("git remote add %s" % (self._url))
                repo.add_remote()
                self._logger.debug("git fetch %s" % (self._name))
                repo.fetch(shallow=True, version=self._version)
                repo.checkout("FETCH_HEAD", quiet=True)
            else:
                self._logger.debug("git clone %s %s" % (self._url, self._name))
                repo = Git.clone(url, path + ".tmp", logger=self._logger)
                self._logger.debug("git fetch %s" % (self._name))
                repo.fetch()
                self._logger.debug("git checkout %s %s" % (self._version, self._name))
                repo.checkout(self._version, quiet=True)
            self._logger.debug("git reset --hard %s" % (self._name))
            repo.reset(hard=True)
            repo.mv(path)
        else:
            raise Exception("%s already exists, please delete" % (path))

    def log_for_revision(self, revision, cache_path=None):
        if cache_path is None:
            with TemporaryDirectory() as dirpath:
                return self._log_for_revision_using_cachedir(revision, dirpath)
        return self._log_for_revision_using_cachedir(revision, cache_path)

    def _log_for_revision_using_cachedir(self, revision, cache_path):
        cache_path = os.path.join(cache_path, self._name)
        if not os.path.exists(cache_path):
            self._logger.debug("git clone %s %s (mirror)" % (self._url, self._name))
            repo = Git.clone(self._url, cache_path, mirror=True, logger=self._logger)
        else:
            repo = Git(self._url, cache_path, logger=self._logger)
            self._logger.debug("git fetch %s (mirror)" % self._name)
            repo.fetch()
        return repo.log_for_revision(revision)


class SpcItemGitBranch(SpcItem):
    def __init__(self, name, url, local_branch, remote_branch, logger=None, opt_arg=None):
        SpcItem.__init__(self, name, logger=logger, opt_arg=opt_arg)
        self._url = url
        self._local_branch = local_branch
        self._remote_branch = remote_branch

    def __eq__(self, other):
        """
        Compare equal for two SpcItemGitBranch components.

        Since the source tree on a branch may change we must be
        conservative and assume that two SpcItemGitBranch items
        are never equivalent.
        """

        return False

    def __hash__(self):
        return hash(id(self))

    def archive_fd(self, fd):
        repo = Git(self._url, None, logger=self._logger)
        repo.archive_fd(self._remote_branch, self._name, fd)

    def archive(self, output_dir):
        repo = Git(self._url, None, logger=self._logger)
        fname = os.path.join(output_dir, self._name + ".tar")
        repo.archive(self._remote_branch, self._name, fname)

    def checkout(self, srcdir, shallow=False, cache_path=None):
        path = os.path.join(srcdir, self._name)
        if not os.path.exists(path):
            if os.path.exists(path + ".tmp"):
                self._logger.debug("rm -rf %s" % (path + ".tmp"))
                rm(path + ".tmp", force=True, recursive=True)
            if shallow:
                self._logger.debug("git init")
                repo = Git.git_init(self._url, path, logger=self._logger)
                self._logger.debug("git remote add %s" % (self._url))
                repo.add_remote()
                self._logger.debug("git fetch %s" % (self._name))
                repo.fetch(shallow, version=self._local_branch)
                repo.checkout(self._local_branch, quiet=True)
            else:
                repo = Git.clone(self._url, path + ".tmp", logger=self._logger)
                if self._remote_branch.startswith("remotes/"):
                    repo.add_branch_fetch()
                    repo.fetch()
                elif self._remote_branch.startswith("vendors/ARM/"):
                    repo.add_arm_vendor_remote()
                    repo.fetch(remote="vendors/ARM")

                if self._remote_branch and self._local_branch != repo.current_branch():
                    branch = self._remote_branch
                    if self._remote_branch.startswith("remotes/"):
                        branch = "remotes/origin/" + self._remote_branch
                    elif self._remote_branch.startswith("vendors/ARM/"):
                        branch = "remotes/" + self._remote_branch
                    else:
                        branch = "origin/" + self._remote_branch
                    repo.branch(branch, self._local_branch)
                repo.checkout(self._local_branch, quiet=True)
                repo.mv(path)
        else:
            raise Exception("%s already exists, please delete" % (path))

class SpcItemSubversionRevision(SpcItem):
    def __init__(self, name, url, revision, logger=None, opt_arg=None):
        SpcItem.__init__(self, name, logger=logger, opt_arg=opt_arg)
        self.url = url
        self.revision = revision

    def __eq__(self, other):
        """
        Compare equal for two SpcItemGitVersion components.
        """

        if self.__class__ != other.__class__:
            return False

        if self.url != other.url:
            return False

        if self.revision != other.revision:
            return False

        return True

    def __hash__(self):
        return hash(self.url) + hash(self.revision)


class SpcItemBldroot(SpcItem):
    def __init__(self, name, channel, status_filter, logger=None, opt_arg=None):
        SpcItem.__init__(self, name, logger=logger, opt_arg=opt_arg)
        self.channel = channel.strip()

        # In order to correctly compare status_filter (__eq__) option
        # we must use and store canonical sorted comma separated list
        if status_filter:
            status_filter = ",".join(sorted(status_filter.split(",")))
        self.status_filter = status_filter

    def __eq__(self, other):
        """
        Compare equal for two SpcItemBldroot components.
        """

        if self.__class__ != other.__class__:
            return False

        if self.channel != other.channel:
            return False

        if self.status_filter != other.status_filter:
            return False

        return True

    def __hash__(self):
        return hash(self.channel) + hash(self.status_filter)

    @staticmethod
    def get_forwardable():
        """This list defines additional attributes which can be forwarded from
        Bldroot property to components frozen based on Bldroot entries.
        """
        return [
            "bldroot-channel",
            "bldroot-tag",
            "bldroot-status",
            "bldroot-status-filter",
        ]

    def checkout(self, srcdir, shallow=False, cache_path=None):
        # Get tag based on channel's filter
        cmd = [
            "bld",
            "build",
            "list",
            self.channel,
            "--status",
            self.status_filter,
            "--count",
            "1",
        ]
        tag = self._cmd_check_output(cmd)
        tag = tag.strip()

        if not tag:
            raise SpcException("unable to resolve TAG name")

        # Store tag's snp/spc file and obtain requested component
        # In case snapshot is not available, use tag's spec file info
        with TemporaryFile() as file_name:
            for artifact_type in ["spc"]:
                cmd = ["bld", "artifact", "exists", artifact_type, tag]
                if not self._cmd_call(cmd):
                    cmd = [
                        "bld",
                        "artifact",
                        "get",
                        "-o",
                        file_name,
                        artifact_type,
                        tag,
                    ]
                    if not self._cmd_call(cmd):
                        spec = Spc.open(file_name)
                        args = {
                            "class": spec[self._name].__class__,
                            "name": self._name,
                            "artifact": artifact_type,
                            "tag": tag,
                        }
                        # To avoid recursion we must only allow Branch/Version items to be frozen
                        if not spec[self._name].__class__ == SpcItemBldroot:
                            msg = "checkout: {class} in component={name}, " "artifact={artifact}, tag={tag}".format(
                                **args
                            )
                            self._logger.debug(msg)
                            self._logger.info("checkout: {name} using " "{artifact} from {tag}".format(**args))
                            return spec[self._name].checkout(srcdir, shallow, cache_path)
                        else:
                            msg = (
                                "found bldroot cycle {class} in component={name}, "
                                "artifact={artifact}, tag={tag}".format(**args)
                            )
                            raise SpcException(msg)
            else:
                raise SpcException("unable to resolve bldroot entry %s" % self._name)

class Spc(object):
    """
    Component version specification.

    Each specification provides the origin of a named component.

    """

    def __init__(self, logger=None):
        self._logger = logger or logging.getLogger(__name__)
        self._items = {}

    @staticmethod
    def open(path, logger=None):
        try:
            return SpcClassicSerializer.open(path, logger)
        except SpcException as classic_reason:
            try:
                return SpcConfigSerializer.open(path, logger)
            except SpcException as config_reason:
                sys.stderr.write("error: cannot read %s\n" % path)
                sys.stderr.write(" classic reader: %s\n" % classic_reason)
                sys.stderr.write(" config reader: %s\n" % config_reason)
                return None

    @staticmethod
    def open_s(xs, name="<???>", logger=None):
        return SpcConfigSerializer.open_s(xs, name, logger)

    def components(self):
        return set(self._items.keys())

    def __getitem__(self, name):
        return self._items[name]

    def __setitem__(self, name, item):
        assert name == item._name
        self._items[name] = item
        item._logger = self._logger

    def __delitem__(self, name):
        del self._items[name]

    def __iter__(self):
        keys = list(self._items.keys())
        keys.sort()
        return keys.__iter__()

    def archive(self, output_dir, component_filter=None):
        for component in self:
            if not component_filter or component_filter(component):
                self[component].archive(output_dir)

    def checkout(self, srcdir, shallow=False, cache_path=None):
        for component in self:
            self[component].checkout(srcdir, shallow, cache_path)

    def __eq__(self, other):
        """
        Compare two SPECs for equivalence.

        Equivalence requires that two specifications must define the
        same set of of named components and each component must be
        defined in the same fashion.  Further each compoents
        specification must result in an identical compoent.
        """

        # Both must have exactly the same set of component names.
        if self.components() != other.components():
            return False

        # Each component must be equal.
        for c in self:
            if self[c] != other[c]:
                return False

        return True

    def __ne__(self, other):
        return not self.__eq__(other)

    def __hash__(self):
        return sum([hash(self[c]) for c in self])


class SpcSerializer(object):
    def __init__(self, spc):
        self._spc = spc

    def write(self, path):
        with open(path, "w") as fd:
            self.write_fd(fd)


class SpcClassicSerializer(SpcSerializer):
    def __init__(self, spc):
        SpcSerializer.__init__(self, spc)

    @staticmethod
    def open_s(xs, name="<???>", logger=None):
        fp = io.StringIO(xs)
        try:
            return SpcClassicSerializer.open_fp(fp, logger)
        finally:
            fp.close()

    @staticmethod
    def open(path, logger=None):
        with open(path, "r") as fp:
            return SpcClassicSerializer.open_fp(fp, logger)

    @staticmethod
    def open_fp(fd, logger=None):
        if logger is None:
            logger = logging.getLogger(__name__)
        spc = Spc(logger)
        for line in fd:
            line, _, _ = line.partition("#")
            parts = line.split()
            if parts == []:
                pass
            elif parts[0] == "git":
                if len(parts) < 2:
                    raise SpcException("error: git requires two arguments")
                name = parts[1]
                url = parts[2]
                typ = parts[3]
                parts = parts[4:]
                if typ == "branch":
                    local_branch = parts[0]
                    remote_branch = None
                    if len(parts) > 1:
                        remote_branch = parts[1]
                        if remote_branch.startswith("origin/"):
                            logger.warning("remote branch prefixed with " "origin/ in %s" % line)
                            remote_branch = remote_branch[7:]

                        if len(parts) > 2:
                            raise SpcException("error: unexpected arguments follow git " "branch")
                    spc[name] = SpcItemGitBranch(name, url, local_branch, remote_branch, logger)
                elif typ == "version" or typ == "hash":
                    version = parts[0]
                    if len(parts) > 1:
                        raise SpcException("error: unexpected arguments " "follow git version/hash")
                    spc[name] = SpcItemGitVersion(name, url, version, logger)
                else:
                    raise SpcException("error: unknown git type %s" % typ)
            elif parts[0] == "svn":
                if len(parts) != 5:
                    raise SpcException("error: svn entry requires " "4 arguments")
                name = parts[1]
                url = parts[2]
                typ = parts[3]
                if typ == "version":
                    revision = parts[4]
                    spc[name] = SpcItemSubversionRevision(name, url, revision, logger)
                else:
                    raise SpcException("error: unknown svn type %s" % typ)
            elif parts[0] == "bldroot":
                if len(parts) != 6:
                    raise SpcException("error: bldroot entry requires " "6 arguments")

                if parts[2] != "channel" or parts[4] != "filter":
                    raise SpcException("error: unknown bldroot entry format" % typ)

                name = parts[1]
                channel = parts[3]
                status_filter = parts[5]
                spc[name] = SpcItemBldroot(name, channel, status_filter, logger)
            elif parts[0] == "tarball":
                if len(parts) < 3 or len(parts) > 4:
                    raise SpcException("error: tarball entry requires " "3 or 4 arguments")
                name = parts[1]
                url = parts[2]
                series = None
                if len(parts) > 3:
                    series = parts[3]
                spc[name] = SpcItemTarball(name, url, series, logger)
            else:
                raise SpcException("error: unknown type %s" % parts[0])
        return spc

    def write_fd(self, fd):
        for component in self._spc:
            item = self._spc[component]
            if item.__class__ == SpcItemTarball:
                fd.write("tarball %s %s" % (item._name, item._url))
                if item._series:
                    fd.write(" %s" % item._series)
                fd.write("\n")
            elif item.__class__ == SpcItemGitBranch:
                fd.write("git %s %s branch %s" % (item._name, item._url, item._local_branch))
                if item._remote_branch:
                    fd.write(" %s" % item._remote_branch)
                fd.write("\n")
            elif item.__class__ == SpcItemGitVersion:
                fd.write("git %s %s version %s\n" % (item._name, item._url, item._version))
            elif item.__class__ == SpcItemSubversionRevision:
                fd.write("svn %s %s version %s\n" % (item._name, item.url, item.revision))
            elif item.__class__ == SpcItemBldroot:
                fd.write("bldroot %s channel %s filter %s\n" % (item._name, item.channel, item.status_filter))
            else:
                raise SpcException("cannot serialize class %s" % item.__class__)


class SpcConfigSerializer(SpcSerializer):
    @staticmethod
    def open_s(xs, name="<???>", logger=None):
        fp = io.StringIO(xs)
        try:
            return SpcConfigSerializer.open_fp(fp, name, logger)
        finally:
            fp.close()

    @staticmethod
    def open(path, logger=None):
        with open(path, "r") as fp:
            return SpcConfigSerializer.open_fp(fp, path, logger)

    @staticmethod
    def open_fp(fp, path, logger=None):
        """Open and parse a 'config' format Spec file returning an Spc."""
        spc = Spc(logger)
        config = configparser.ConfigParser()
        config.read_file(fp)
        for section in config.sections():
            name = section
            if config.has_option(name, "type"):
                type = config.get(name, "type")
                if type == "tarball":
                    url = None
                    series = None
                    opt_arg = {}
                    for option in config.options(name):
                        if option == "type":
                            pass
                        elif option == "url":
                            url = config.get(name, option)
                        elif option == "series":
                            series = config.get(name, option)
                        elif option in SpcItemBldroot.get_forwardable():
                            opt_arg[option] = config.get(name, option)
                        else:
                            raise SpcException("unknown option '%s'" % option)
                    if url is None:
                        raise SpcException("%s has no url option" % name)
                    spc[name] = SpcItemTarball(name, url, series, logger, opt_arg=opt_arg)
                elif type == "git":
                    url = None
                    version = None
                    local_branch = None
                    remote_branch = None
                    opt_arg = {}
                    for option in config.options(name):
                        if option == "type":
                            pass
                        elif option == "url":
                            url = config.get(name, option)
                        elif option == "version":
                            version = config.get(name, option)
                        elif option == "branch":
                            local_branch = config.get(name, option)
                        elif option == "remote-branch":
                            remote_branch = config.get(name, option)
                            if remote_branch.startswith("origin/"):
                                logger.warning("remote branch prefixed with " "origin/  %s" % path)
                                remote_branch = remote_branch[7:]
                        elif option in SpcItemBldroot.get_forwardable():
                            opt_arg[option] = config.get(name, option)
                        else:
                            raise SpcException("unknown option '%s'" % option)

                    if version:
                        if local_branch or remote_branch:
                            raise SpcException("%s has both version and " "branch options" % name)
                        spc[name] = SpcItemGitVersion(name, url, version, logger, opt_arg=opt_arg)
                    else:
                        if version:
                            raise SpcException("%s has both branch and " "version options" % name)
                        if url is None:
                            raise SpcException("%s has no url option" % name)

                        if remote_branch is None:
                            remote_branch = "master"

                        if local_branch is None:
                            local_branch = "master"

                        spc[name] = SpcItemGitBranch(
                            name,
                            url,
                            local_branch,
                            remote_branch,
                            logger,
                            opt_arg=opt_arg,
                        )
                elif type == "subversion":
                    url = None
                    revision = None
                    opt_arg = {}
                    for option in config.options(name):
                        if option == "type":
                            pass
                        elif option == "url":
                            url = config.get(name, option)
                        elif option == "revision":
                            revision = config.get(name, option)
                        elif option in SpcItemBldroot.get_forwardable():
                            opt_arg[option] = config.get(name, option)
                        else:
                            raise SpcException("unknown option '%s'" % option)

                    spc[name] = SpcItemSubversionRevision(name, url, revision, logger, opt_arg=opt_arg)
                elif type == "bldroot":
                    channel = None
                    status_filter = None
                    for option in config.options(name):
                        if option == "type":
                            pass
                        elif option == "channel":
                            channel = config.get(name, option)
                        elif option == "status-filter":
                            status_filter = config.get(name, option)
                        else:
                            raise SpcException("unknown option '%s'" % option)

                    spc[name] = SpcItemBldroot(name, channel, status_filter, logger)
                else:
                    raise SpcException("unknown type '%s'" % type)
            else:
                raise SpcException("component without type")
        return spc

    def write_fd(self, fd):
        for component in self._spc:
            item = self._spc[component]
            fd.write("[%s]\n" % item._name)
            if item.__class__ == SpcItemTarball:
                fd.write("type=tarball\n")
                fd.write("url=%s\n" % item._url)
                if item._series:
                    fd.write("series=%s\n" % item._series)
            elif item.__class__ == SpcItemGitBranch:
                fd.write("type=git\n")
                fd.write("url=%s\n" % item._url)
                fd.write("branch=%s\n" % item._local_branch)
                if item._remote_branch:
                    fd.write("remote-branch=%s\n" % item._remote_branch)
            elif item.__class__ == SpcItemGitVersion:
                fd.write("type=git\n")
                fd.write("url=%s\n" % item._url)
                fd.write("version=%s\n" % item._version)
            elif item.__class__ == SpcItemSubversionRevision:
                fd.write("type=subversion\n")
                fd.write("url=%s\n" % item.url)
                fd.write("revision=%s\n" % item.revision)
            elif item.__class__ == SpcItemBldroot:
                fd.write("type=bldroot\n")
                fd.write("channel=%s\n" % item.channel)
                fd.write("status-filter=%s\n" % item.status_filter)
            else:
                raise SpcException("cannot serialize class %s" % item.__class__)

            if item.opt_attr():
                for k, v in list(item.opt_attr().items()):
                    fd.write("%s=%s\n" % (k, v))

            fd.write("\n")


class ExternalTransformException(Exception):
    def __init__(self, value):
        self.value = value

    def __str__(self):
        return "Component --transform-file parse error: " + self.value


def create_logger(verbose):
    logger = logging.getLogger()
    logger.setLevel(logging.WARNING)

    handler = logging.StreamHandler()
    handler.setLevel(logging.WARNING)

    if verbose == 1:
        logger.setLevel(logging.INFO)
        handler.setLevel(logging.INFO)
    elif verbose > 1:
        logger.setLevel(logging.DEBUG)
        handler.setLevel(logging.DEBUG)

    formatter = logging.Formatter("%(asctime)s %(levelname)s::%(name)s %(message)s")
    handler.setFormatter(formatter)

    logger.addHandler(handler)
    return logger


def do_archive(args):
    spc = Spc.open(args.SPCFILE[0])

    def f(c):
        return args.components == [] or c in args.components

    # The IOError raised when attempting to write into the none
    # existent directory specified the PATH of the file rather than
    # the directory resulting in a confusing error message.  Look
    # explicitly for that case and report it.
    if not os.path.exists(args.output_dir):
        sys.stderr.write("error: no such directory: %s\n" % args.output_dir)
        return 3

    try:
        spc.archive(args.output_dir, component_filter=f)
    except IOError as e:
        sys.stderr.write("error: %s\n" % str(e))
        return 3
    return 0


def do_checkout(args):
    spc = Spc.open(args.SPCFILE[0])
    spc.checkout(args.srcdir, args.shallow, cache_path=args.cachedir)
    return 0

class Extend(argparse.Action):
    def __init__(self, option_strings, dest, nargs=None, **kwargs):
        if nargs is not None:
            raise ValueError("nargs not allowed")
        super(Extend, self).__init__(option_strings, dest, **kwargs)

    def __call__(self, parser, namespace, values, option_string=None):
        xs = getattr(namespace, self.dest)
        if xs is None:
            xs = []
        xs.extend(values)
        setattr(namespace, self.dest, xs)

def main_(args):
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description="Utility to fetch upstream projects based on SPEC manifest files.",
        epilog=__doc__,
    )
    parser.add_argument(
        "--cache-dir",
        action="store",
        metavar="DIR",
        dest="cachedir",
        help="Specify a cache directory.",
    )
    parser.add_argument("-v", "--verbose", action="count", default=0, help="Increase verbosity.")
    subparsers = parser.add_subparsers(dest="command")
    sub = subparsers.add_parser("archive", help="Generate tarballs from a SPEC file.")

    sub.add_argument(
        "--components",
        action=Extend,
        metavar="COMPONENT",
        type=lambda xs: xs.split(","),
        help="Filter output to include only COMPONENT.",
        default=[],
    )
    sub.add_argument(
        "-o",
        "--output-dir",
        action="store",
        default=".",
        help="Specify an output directory, default current directory.",
    )
    sub.add_argument("SPCFILE", nargs=1)
    sub = subparsers.add_parser("checkout", help="Checkout full source trees from SPEC file.")
    sub.add_argument(
        "--srcdir",
        "--src-dir",
        action="store",
        metavar="DIR",
        default=".",
        help="Specify a source directory.",
    )
    sub.add_argument(
        "--shallow",
        action="store_true",
        default=False,
        help="Do shallow checkout.",
    )
    sub.add_argument("SPCFILE", nargs=1)

    args = parser.parse_args(args)

    logger = create_logger(args.verbose)
    try:
        if args.command == "archive":
            return do_archive(args)
        elif args.command == "checkout":
            return do_checkout(args)
        return 0

    except KeyError as e:
        sys.stderr.write("error: %s\n" % str(e))
        return 3
    except GitException as e:
        sys.stderr.write("error: %s\n" % str(e))
        return 4
    except SpcException as e:
        sys.stderr.write("error: %s\n" % str(e))
        return 5
    except ExternalTransformException as e:
        sys.stderr.write("error: %s\n" % str(e))
        return 6


def main():
    sys.exit(main_(sys.argv[1:]))


if __name__ == "__main__":
    main()
