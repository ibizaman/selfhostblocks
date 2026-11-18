import contextlib
import io
import runpy
import subprocess
import sys
import typing
import unittest
from unittest import mock

import sanoid_restore


class _RestoreTests(unittest.TestCase):
    @typing.override
    def setUp(self) -> None:
        self.zfs = self.enterContext(mock.patch("subprocess.run"))
        self.zfs.return_value = subprocess.CompletedProcess(["zfs"], 0, "", "")
        self.snapshot = f"{sanoid_restore.dataset}@test-only"

    def _invoke(self, *args: str) -> tuple[int, str, str]:
        status = 0
        with (
            io.StringIO() as stdout,
            io.StringIO() as stderr,
            mock.patch.object(sys, "argv", ["sanoid-restore", *args]),
            contextlib.redirect_stdout(stdout),
            contextlib.redirect_stderr(stderr),
        ):
            try:
                runpy.run_path("sanoid_restore.py", run_name="__main__")
            except SystemExit as error:
                assert isinstance(error.code, int)
                status = error.code
            return status, stdout.getvalue(), stderr.getvalue()

    def test_rejects_foreign_and_malformed_snapshots_before_running_zfs(self) -> None:
        flag_sets: list[list[str]] = [[], ["--destroy-newer-snapshots"]]
        for snapshot in [
            f"other/{sanoid_restore.dataset}@test-only",
            f"{sanoid_restore.dataset}/child@test-only",
            f"{sanoid_restore.dataset}2@test-only",
            "test-only",
            f"{sanoid_restore.dataset}@",
            f"{sanoid_restore.dataset}@one@two",
        ]:
            for flags in flag_sets:
                with self.subTest(snapshot=snapshot, flags=flags):
                    self.zfs.reset_mock()
                    status, _, _ = self._invoke("restore", *flags, snapshot)
                    self.assertNotEqual(status, 0)
                    self.zfs.assert_not_called()

    def test_default_restore_does_not_authorize_snapshot_deletion(self) -> None:
        status, _, _ = self._invoke("restore", self.snapshot)
        self.assertEqual(status, 0)
        self.assertEqual(self.zfs.call_args.args[0], ["zfs", "rollback", self.snapshot])

    def test_snapshot_deletion_requires_explicit_flag(self) -> None:
        status, _, _ = self._invoke(
            "restore", "--destroy-newer-snapshots", self.snapshot
        )
        self.assertEqual(status, 0)
        self.assertEqual(
            self.zfs.call_args.args[0], ["zfs", "rollback", "-r", self.snapshot]
        )

    def test_zfs_refusal_is_reported_without_retry(self) -> None:
        self.zfs.side_effect = subprocess.CalledProcessError(
            1, ["zfs", "rollback", self.snapshot], stderr="more recent snapshots exist"
        )
        status, _, stderr = self._invoke("restore", self.snapshot)
        self.assertNotEqual(status, 0)
        self.assertIn("more recent snapshots exist", stderr)
        self.assertEqual(self.zfs.call_count, 1)
        self.assertNotIn("-r", self.zfs.call_args.args[0])

    def test_lists_only_the_configured_dataset(self) -> None:
        self.zfs.return_value = subprocess.CompletedProcess(
            ["zfs"], 0, f"{self.snapshot}\n", ""
        )
        status, stdout, _ = self._invoke("snapshots")
        self.assertEqual(status, 0)
        self.assertEqual(stdout, f"{self.snapshot}\n")
        self.assertEqual(
            self.zfs.call_args.args[0],
            ["zfs", "list", "-H", "-t", "snapshot", sanoid_restore.dataset],
        )

    def test_empty_snapshot_list(self) -> None:
        status, stdout, _ = self._invoke("snapshots")
        self.assertEqual(status, 0)
        self.assertEqual(stdout, "")
