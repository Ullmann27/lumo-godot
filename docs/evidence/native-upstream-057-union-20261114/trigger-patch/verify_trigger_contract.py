#!/usr/bin/env python3
"""Read actual workflow YAML and verify only the authorized trigger delta."""

import ast
import copy
import hashlib
import json
from pathlib import Path
import subprocess

import yaml


ROOT = Path(__file__).resolve().parent
ORIGINAL = ROOT / "workflow-before.yml"
PATCHED = ROOT / ".github/workflows/lumo-discovery-connections.yml"
JOB = "discovery-native-acceptance"
REPOSITORY = "Ullmann27/lumo-godot"
BRANCHES = (
    "integration/lumo-discovery-bd-20261114",
    "integration/lumo-live-connections-20261114",
)


def evaluate(node, context):
    """Evaluate the exact limited string/boolean expression used by this job."""
    if isinstance(node, ast.Expression):
        return evaluate(node.body, context)
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    if (
        isinstance(node, ast.Attribute)
        and isinstance(node.value, ast.Name)
        and node.value.id == "github"
        and node.attr in {"repository", "event_name", "ref"}
    ):
        return context[node.attr]
    if isinstance(node, ast.BoolOp) and isinstance(node.op, (ast.And, ast.Or)):
        values = [evaluate(value, context) for value in node.values]
        assert all(isinstance(value, bool) for value in values)
        return all(values) if isinstance(node.op, ast.And) else any(values)
    if (
        isinstance(node, ast.Compare)
        and len(node.ops) == len(node.comparators) == 1
        and isinstance(node.ops[0], ast.Eq)
    ):
        left = evaluate(node.left, context)
        right = evaluate(node.comparators[0], context)
        assert isinstance(left, str) and isinstance(right, str)
        # GitHub expression string equality is case-insensitive.
        return left.casefold() == right.casefold()
    raise AssertionError(f"Unexpected expression syntax: {ast.dump(node)}")


def main():
    before = yaml.load(ORIGINAL.read_text(), Loader=yaml.BaseLoader)
    after = yaml.load(PATCHED.read_text(), Loader=yaml.BaseLoader)
    assert before["on"] == {"push": {"branches": [BRANCHES[0]]}}
    assert after["on"] == {"push": {"branches": list(BRANCHES)}}
    assert after["concurrency"]["cancel-in-progress"] == "false"
    assert after["concurrency"]["group"] == "lumo-discovery-connections-${{ github.ref }}"
    old_job, new_job = before["jobs"][JOB], after["jobs"][JOB]
    assert old_job["timeout-minutes"] == new_job["timeout-minutes"] == "130"
    assert old_job["steps"] == new_job["steps"]
    restored = copy.deepcopy(after)
    restored["on"] = before["on"]
    restored["concurrency"]["group"] = before["concurrency"]["group"]
    restored["jobs"][JOB]["if"] = old_job["if"]
    assert restored == before, "An unrelated workflow value changed"

    blocks = [step for step in new_job["steps"] if "run" in step]
    assert len(blocks) == 12
    block_results = []
    for number, step in enumerate(blocks, 1):
        checked = subprocess.run(
            ["bash", "-n"], input=step["run"], text=True, capture_output=True
        )
        assert checked.returncode == 0, checked.stderr
        block_results.append({
            "number": number,
            "name": step["name"],
            "sha256": hashlib.sha256(step["run"].encode()).hexdigest(),
            "bash_n_exit": checked.returncode,
            "stdout": checked.stdout,
            "stderr": checked.stderr,
        })

    expression = new_job["if"].replace("&&", " and ").replace("||", " or ")
    parsed = ast.parse(expression.strip(), mode="eval")
    cases = [
        ("existing producer push", REPOSITORY, "push", "refs/heads/" + BRANCHES[0], True),
        ("integrated source push", REPOSITORY, "push", "refs/heads/" + BRANCHES[1], True),
        ("foreign main", REPOSITORY, "push", "refs/heads/main", False),
        ("similar branch suffix", REPOSITORY, "push", "refs/heads/" + BRANCHES[1] + "-other", False),
        ("similar branch prefix", REPOSITORY, "push", "refs/heads/other-" + BRANCHES[0], False),
        ("tag with allowed spelling", REPOSITORY, "push", "refs/tags/" + BRANCHES[1], False),
        ("fork repository", "another-owner/lumo-godot", "push", "refs/heads/" + BRANCHES[1], False),
        ("other repository", "Ullmann27/lumo-lernen", "push", "refs/heads/" + BRANCHES[0], False),
        ("pull request event", REPOSITORY, "pull_request", "refs/heads/" + BRANCHES[1], False),
        ("manual event", REPOSITORY, "workflow_dispatch", "refs/heads/" + BRANCHES[0], False),
        ("pull request merge ref", REPOSITORY, "push", "refs/pull/173/merge", False),
        ("wrong repository plus foreign ref", "another-owner/lumo-godot", "push", "refs/heads/main", False),
    ]
    case_results = []
    for label, repository, event, ref, expected in cases:
        context = {"repository": repository, "event_name": event, "ref": ref}
        job_if = evaluate(parsed, context)
        # Both patterns are asserted literal branch names above, without globs.
        push_filter = event == "push" and ref.startswith("refs/heads/") and ref[11:] in BRANCHES
        assert job_if is expected, (label, job_if, expected)
        assert (push_filter and job_if) is expected, label
        case_results.append({"case": label, **context, "push_filter": push_filter,
                             "job_if": job_if, "will_run": push_filter and job_if,
                             "expected": expected})
    groups = [after["concurrency"]["group"].replace("${{ github.ref }}", "refs/heads/" + branch)
              for branch in BRANCHES]
    assert groups[0] != groups[1]
    result = {
        "scope": "Static workflow contract; no GitHub workflow or Godot test launched",
        "source_commit": "fe861bd09296ef0051887dc21f48ca38215fc76b",
        "only_authorized_semantic_fields_changed": True,
        "original_steps_equal": True,
        "upload_steps_equal": True,
        "timeout_minutes": 130,
        "cancel_in_progress": False,
        "original_run_blocks": block_results,
        "cases": case_results,
        "distinct_allowed_ref_concurrency_groups": groups,
        "all_passed": True,
    }
    (ROOT / "trigger-contract-result.json").write_text(json.dumps(result, indent=2) + "\n")
    print("[DiscoveryTriggerContract] PASS 12 source-identical run blocks, 12 ref/event/repository cases; timeout and upload unchanged")


if __name__ == "__main__":
    main()
