"""Real filesystem faults: an unsuccessful save must preserve the old file."""
import os
import ctypes
import pathlib
import resource
import signal
import subprocess
import sys
import tempfile
import unittest

EXE = sys.argv.pop(1)

class Transactions(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        self.file = self.root / 'source.cpp'
        self.file.write_bytes(b'previous valid contents')

    def run_save(self, mode='write', path=None, text='new contents', **kwargs):
        return subprocess.run([EXE, mode, str(path or self.file), text],
                              capture_output=True, **kwargs)

    def assert_preserved(self):
        self.assertEqual(self.file.read_bytes(), b'previous valid contents')
        self.assertFalse(list(self.root.glob('.penguin-save-*')))

    def test_commit_and_empty_file(self):
        self.assertEqual(self.run_save().returncode, 0)
        self.assertEqual(self.file.read_text(), 'new contents')
        self.assertEqual(self.run_save(text='').returncode, 0)
        self.assertEqual(self.file.stat().st_size, 0)

    def test_partial_write_failure(self):
        def limit_file():
            signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
            resource.setrlimit(resource.RLIMIT_FSIZE, (16, 16))
        result = self.run_save(text='x' * 8192, preexec_fn=limit_file)
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assert_preserved()

    def test_readonly(self):
        self.file.chmod(0o444)
        self.assertNotEqual(self.run_save().returncode, 0)
        self.assert_preserved()

    def test_metadata(self):
        self.file.chmod(0o640)
        key = 'user.penguin-test' if sys.platform != 'darwin' else 'penguin-test'
        if sys.platform == 'darwin':
            libc = ctypes.CDLL(None, use_errno=True)
            self.assertEqual(libc.setxattr(os.fsencode(self.file), key.encode(), b'keep', ctypes.c_size_t(4), 0, 0), 0)
        else:
            os.setxattr(self.file, key, b'keep')
        self.assertEqual(self.run_save().returncode, 0)
        self.assertEqual(self.file.stat().st_mode & 0o777, 0o640)
        if sys.platform == 'darwin':
            value = ctypes.create_string_buffer(16)
            self.assertEqual(libc.getxattr(os.fsencode(self.file), key.encode(), value, ctypes.c_size_t(16), 0, 0), 4)
            self.assertEqual(value.raw[:4], b'keep')
        else:
            self.assertEqual(os.getxattr(self.file, key), b'keep')

    def test_symlink(self):
        link = self.root / 'link.cpp'
        link.symlink_to(self.file.name)
        self.assertEqual(self.run_save(path=link).returncode, 0)
        self.assertTrue(link.is_symlink())
        self.assertEqual(self.file.read_text(), 'new contents')

    def test_hardlink_fails_safely(self):
        os.link(self.file, self.root / 'alias.cpp')
        self.assertNotEqual(self.run_save().returncode, 0)
        self.assert_preserved()

    def test_invalid_destination(self):
        directory = self.root / 'directory'
        directory.mkdir()
        self.assertNotEqual(self.run_save(path=directory).returncode, 0)
        self.assertTrue(directory.is_dir())
        self.assert_preserved()

    def test_ini_discard_and_explicit_commit(self):
        self.file.write_text('[Project]\nName=old\n')
        self.assertEqual(self.run_save('discard', text='unsaved').returncode, 0)
        self.assertEqual(self.file.read_text(), '[Project]\nName=old\n')
        self.assertEqual(self.run_save('commit', text='saved').returncode, 0)
        self.assertIn('Name=saved', self.file.read_text())

unittest.main(verbosity=2)
