#!/usr/bin/env python3
"""Check that the world runner rejects incomplete engine receipts.

These fixtures exercise log acceptance only. They do not simulate a Godot
geometry result and must not be reported as real-world or rendering evidence.
"""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


RUNNER = Path(__file__).with_name("test_track_theme_world.py")


def receipt(
    track: str = "learning_lab",
    probes: tuple[int, ...] = (4,),
    support: str = "geometry_probed",
    total: int | None = None,
    failures: int = 0,
) -> str:
    qualities = ("light",) if len(probes) == 1 else ("light", "full")
    cases = [
        f"[ThemeWorld] CASE {track}/{quality} accepted=1 unaccepted_slots=0 "
        f"parts=4 support={support} support_probes={count} failures={failures}"
        for quality, count in zip(qualities, probes)
    ]
    cases.append(
        f"[ThemeWorld] PASS cases={len(cases)} checks=20 "
        f"support_probes={sum(probes) if total is None else total}; "
        "camera/device performance not assessed"
    )
    return "\n".join(cases) + "\n"


class ReceiptAcceptance(unittest.TestCase):
    def run_receipt(
        self, log: str, expected_exit: int, *, track: str = "learning_lab",
        quality: str = "light",
    ) -> None:
        with tempfile.TemporaryDirectory(prefix="lumo-world-runner-contract-") as temporary:
            root = Path(temporary)
            fixture_engine = root / "receipt_engine"
            fixture_engine.write_text(
                f"#!{sys.executable}\nimport sys\nsys.stdout.write({log!r})\n"
            )
            fixture_engine.chmod(0o700)
            result = subprocess.run(
                [sys.executable, str(RUNNER), "--godot", str(fixture_engine),
                 "--track", track, "--quality", quality, "--out", str(root / "evidence")],
                capture_output=True, text=True, timeout=30,
            )
            self.assertEqual(result.returncode, expected_exit, result.stdout + result.stderr)

    def test_accepts_complete_ground_receipt(self) -> None:
        self.run_receipt(receipt(), 0)

    def test_accepts_explicitly_unassessed_floating_world(self) -> None:
        self.run_receipt(
            receipt("galaxy_ringway", (0,), "NOT_ASSESSED"), 0, track="galaxy_ringway"
        )

    def test_rejects_disabled_ground_coverage(self) -> None:
        self.run_receipt(receipt(support="NOT_ASSESSED"), 1)

    def test_rejects_zero_ground_probes(self) -> None:
        self.run_receipt(receipt(probes=(0,)), 1)

    def test_rejects_missing_case_probe_count(self) -> None:
        self.run_receipt(receipt().replace(" support_probes=4 failures=", " failures="), 1)

    def test_rejects_inconsistent_probe_total(self) -> None:
        self.run_receipt(receipt(total=40), 1)

    def test_rejects_one_unprobed_quality(self) -> None:
        self.run_receipt(receipt(probes=(4, 0)), 1, quality="both")

    def test_rejects_case_failure_despite_pass_marker(self) -> None:
        self.run_receipt(receipt(failures=1), 1)

    def test_rejects_engine_error_despite_pass_marker(self) -> None:
        self.run_receipt(receipt() + "ERROR: fixture failure\n", 1)


if __name__ == "__main__":
    unittest.main()
