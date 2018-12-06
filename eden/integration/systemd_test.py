#!/usr/bin/env python3
#
# Copyright (c) 2016-present, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree. An additional grant
# of patent rights can be found in the PATENTS file in the same directory.

import pathlib
import subprocess
import sys
import typing
import unittest

import pexpect
from eden.test_support.temporary_directory import TemporaryDirectoryMixin

from .lib.edenfs_systemd import EdenFSSystemdMixin
from .lib.environment_variable import EnvironmentVariableMixin
from .lib.find_executables import FindExe
from .lib.systemd import SystemdUserServiceManagerMixin


class SystemdTest(
    unittest.TestCase,
    EnvironmentVariableMixin,
    TemporaryDirectoryMixin,
    SystemdUserServiceManagerMixin,
    EdenFSSystemdMixin,
):
    """Test Eden's systemd service for Linux."""

    def setUp(self) -> None:
        super().setUp()

        self.set_environment_variable("EDEN_EXPERIMENTAL_SYSTEMD", "1")
        self.eden_dir = self.make_temporary_directory()

    # TODO(T33122320): Delete this test when systemd is properly integrated.
    # TODO(T33122320): Test without --foreground.
    def test_eden_start_says_systemd_mode_is_enabled(self) -> None:
        def test(start_args: typing.List[str]) -> None:
            with self.subTest(start_args=start_args):
                start_process: "pexpect.spawn[str]" = pexpect.spawn(
                    FindExe.EDEN_CLI,
                    ["--config-dir", self.eden_dir, "start", "--foreground"]
                    + start_args,
                    encoding="utf-8",
                    logfile=sys.stderr,
                )
                start_process.expect_exact("Running in experimental systemd mode")
                start_process.expect_exact("Started edenfs")

        test(start_args=["--", "--allowRoot"])
        test(start_args=["--daemon-binary", FindExe.FAKE_EDENFS])

    # TODO(T33122320): Delete this test when systemd is properly integrated.
    def test_eden_start_with_systemd_disabled_does_not_say_systemd_mode_is_enabled(
        self
    ) -> None:
        self.unset_environment_variable("EDEN_EXPERIMENTAL_SYSTEMD")

        def test(start_args: typing.List[str]) -> None:
            with self.subTest(start_args=start_args):
                start_process: "pexpect.spawn[str]" = pexpect.spawn(
                    FindExe.EDEN_CLI,
                    ["--config-dir", self.eden_dir, "start", "--foreground"]
                    + start_args,
                    encoding="utf-8",
                    logfile=sys.stderr,
                )
                start_process.expect_exact("Started edenfs")
                self.assertNotIn(
                    "Running in experimental systemd mode", start_process.before
                )

        test(start_args=["--", "--allowRoot"])
        test(start_args=["--daemon-binary", FindExe.FAKE_EDENFS])

    def test_eden_start_starts_systemd_service(self) -> None:
        self.set_up_edenfs_systemd_service()
        subprocess.check_call(
            [
                FindExe.EDEN_CLI,
                "--config-dir",
                self.eden_dir,
                "start",
                "--daemon-binary",
                FindExe.FAKE_EDENFS,
            ]
        )
        self.assert_systemd_service_is_active()

    def assert_systemd_service_is_active(self) -> None:
        service = self.get_edenfs_systemd_service(eden_dir=pathlib.Path(self.eden_dir))
        self.assertEqual(
            (service.query_active_state(), service.query_sub_state()),
            ("active", "running"),
            f"EdenFS systemd service ({service}) should be running",
        )
