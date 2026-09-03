"""Map changed file paths to affected {environment, account_id} deployment
targets.

Used both locally and in CI to guarantee account-isolated deployment: a
change under one account's request tree must only ever select that
account, and changes to shared modules/ or guardrails/ must never
auto-select every account (they require an explicit rollout manifest).

Note: the deployable unit is the *account* -- one Terraform state file
covers every user/role/policy/group for that account (see
live/<env>/<account_id>/terragrunt.hcl) -- not the account+component pair.
A change under requests/<env>/<account_id>/roles/... and one under
requests/<env>/<account_id>/users/... both resolve to the same single
target and dedupe together, because they'd be planned/applied in the same
Terragrunt unit either way.
"""

import json
import os
import re
import sys

REQUEST_PATH_RE = re.compile(
    r"^requests/(?P<environment>[^/]+)/(?P<account_id>[^/]+)/(?P<component>[^/]+)/"
)
COMMON_PATH_RE = re.compile(r"^requests/common/(?P<component>[^/]+)/")

CONTROLLED_ROLLOUT_PREFIXES = ("modules/", "guardrails/")

CONTROLLED_ROLLOUT_MESSAGE = (
    "Changes under modules/ or guardrails/ require an explicit rollout "
    "manifest (--rollout-manifest) -- refusing to auto-select all "
    "accounts. Provide a manifest listing the accounts to roll out, or "
    "run a scoped manual plan."
)


def _normalize(path):
    return path.replace(os.sep, "/").lstrip("./")


def _discover_common_targets(requests_root, component):
    """Find every {environment, account_id} that has a `component`
    directory under requests_root, for requests/common/<component>/ fanout.
    """
    targets = []
    if not os.path.isdir(requests_root):
        return targets

    for environment in sorted(os.listdir(requests_root)):
        if environment == "common":
            continue
        env_dir = os.path.join(requests_root, environment)
        if not os.path.isdir(env_dir):
            continue
        for account_id in sorted(os.listdir(env_dir)):
            component_dir = os.path.join(env_dir, account_id, component)
            if os.path.isdir(component_dir):
                targets.append({"environment": environment, "account_id": account_id})
    return targets


def _load_rollout_manifest(manifest_path):
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)
    return manifest.get("targets", [])


def classify_paths(paths, requests_root="requests", rollout_manifest=None):
    controlled_rollout_required = False
    message = None
    targets = []

    for raw_path in paths:
        path = _normalize(raw_path)

        if path.startswith(CONTROLLED_ROLLOUT_PREFIXES):
            if rollout_manifest:
                targets.extend(_load_rollout_manifest(rollout_manifest))
            else:
                controlled_rollout_required = True
                message = CONTROLLED_ROLLOUT_MESSAGE
            continue

        common_match = COMMON_PATH_RE.match(path)
        if common_match:
            targets.extend(
                _discover_common_targets(requests_root, common_match.group("component"))
            )
            continue

        match = REQUEST_PATH_RE.match(path)
        if match:
            targets.append(
                {
                    "environment": match.group("environment"),
                    "account_id": match.group("account_id"),
                }
            )
            continue

        # Unrecognized path (e.g. README.md) -- not a deployable target.

    deduped = sorted({(t["environment"], t["account_id"]) for t in targets})
    result_targets = [{"environment": e, "account_id": a} for e, a in deduped]

    return {
        "controlled_rollout_required": controlled_rollout_required,
        "message": message,
        "targets": result_targets,
    }


def main(argv):
    rollout_manifest = None
    paths_argv = list(argv)
    if "--rollout-manifest" in paths_argv:
        idx = paths_argv.index("--rollout-manifest")
        rollout_manifest = paths_argv[idx + 1]
        del paths_argv[idx : idx + 2]

    if paths_argv:
        paths = paths_argv
    else:
        paths = [line.strip() for line in sys.stdin if line.strip()]

    result = classify_paths(paths, rollout_manifest=rollout_manifest)
    print(json.dumps(result, indent=2, sort_keys=True))

    if result["controlled_rollout_required"]:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
