"""Exercise installer rollback against disposable app bundles and mocked OS tools."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

INSTALLER = Path(__file__).resolve().parents[3] / 'packaging/install-macos.sh'


class InstallTest(unittest.TestCase):
    def run_case(self, failure):
        with tempfile.TemporaryDirectory(prefix='penguin-install-test-') as tmp:
            root = Path(tmp)
            tools = root / 'bin'
            tools.mkdir()
            dest = root / 'Applications with spaces'
            previous = dest / "Penguin's QA.app"
            previous.mkdir(parents=True)
            (previous / 'version').write_text('old')
            scripts = {
                'uname': 'if [ "$1" = -s ]; then echo Darwin; else echo arm64; fi',
                'sw_vers': 'if [ "$FAILURE" = oldmac ]; then echo 15.7; else echo 26.0; fi',
                'pgrep': 'exit 1',
                'curl': 'case "$*" in *url_effective*) printf %s https://github.com/JuanFranG/Penguin-cpp/releases/tag/v0.2.3;; esac',
                'hdiutil': 'if [ "$1" = attach ]; then while [ "$1" != -mountpoint ]; do shift; done; shift; mkdir -p "$1/Penguin cpp.app"; echo new > "$1/Penguin cpp.app/version"; fi',
                'codesign': 'if [ "$FAILURE" = verify ] && [ -f "$VERIFY_SEEN" ]; then exit 1; fi; touch "$VERIFY_SEEN"',
                'ditto': 'if [ "$FAILURE" = copy ]; then mkdir -p "$2"; exit 1; fi; /bin/cp -R "$1" "$2"',
                'mv': r'case "$1" in */Penguin\ cpp.app) if [ "$FAILURE" = rename ]; then exit 1; fi;; esac; exec /bin/mv "$@"',
                'xcode-select': 'exit 0',
            }
            for name, body in scripts.items():
                path = tools / name
                path.write_text('#!/bin/bash\nset -eu\n' + body + '\n')
                path.chmod(0o700)
            env = dict(os.environ, PATH=str(tools)+':/usr/bin:/bin',
                       INSTALL_DIR=str(dest), INSTALL_APP_NAME=previous.name,
                       FAILURE=failure, VERIFY_SEEN=str(root/'verified'), TMPDIR=str(root))
            result = subprocess.run(['/bin/bash', str(INSTALLER)], env=env,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode == 0, failure == '', result.stdout+result.stderr)
            self.assertEqual((previous/'version').read_text().strip(), 'old' if failure else 'new')
            self.assertEqual(list(dest.glob('.penguin-cpp-update.*')), [])

    def test_success(self): self.run_case('')
    def test_partial_copy_keeps_old_app(self): self.run_case('copy')
    def test_failed_verification_keeps_old_app(self): self.run_case('verify')
    def test_failed_rename_restores_old_app(self): self.run_case('rename')
    def test_old_macos_is_rejected_without_changing_app(self): self.run_case('oldmac')


if __name__ == '__main__': unittest.main()
