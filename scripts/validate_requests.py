"""Local guardrail validation for IAM platform request files.

Validates request.yaml files under requests/**, and the policy JSON
documents they reference, against the guardrails defined in
guardrails/allowed-aws-managed-policies.yaml and
guardrails/prohibited-actions.yaml. Runs entirely offline: no AWS
credentials or network access required. If the AWS CLI happens to be
installed, IAM Access Analyzer policy validation is run as a best-effort,
non-fatal extra check.
"""

import datetime
import json
import os
import re
import shutil
import subprocess
import sys

import yaml

ACCOUNT_ID_RE = re.compile(r"^\d{12}$")


def _path_components(path):
    """Derive {environment, account_id, component} from a request.yaml
    path by walking up from its parent directories:
    .../<environment>/<account_id>/<component>/<name>/request.yaml
    Works regardless of what precedes <environment> (a real "requests/"
    tree, or a test fixture directory), since only the last four path
    segments carry meaning.
    """
    name_dir = os.path.dirname(os.path.abspath(path))
    component_dir = os.path.dirname(name_dir)
    account_dir = os.path.dirname(component_dir)
    env_dir = os.path.dirname(account_dir)
    return {
        "environment": os.path.basename(env_dir),
        "account_id": os.path.basename(account_dir),
        "component": os.path.basename(component_dir),
    }


class ValidationError(Exception):
    def __init__(self, errors):
        super().__init__("; ".join(errors))
        self.errors = errors


def discover_requests(root):
    found = []
    for dirpath, _dirnames, filenames in os.walk(root):
        if "request.yaml" in filenames:
            found.append(os.path.join(dirpath, "request.yaml"))
    return sorted(found)


def load_request(path):
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def _load_guardrail_yaml(guardrails_dir, filename):
    with open(os.path.join(guardrails_dir, filename), "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def _as_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def _check_policy_document(policy_doc, prohibited_prefixes, wildcard_allowed_actions, source_label, errors):
    statements = _as_list(policy_doc.get("Statement"))
    for statement in statements:
        actions = [str(a) for a in _as_list(statement.get("Action"))]
        resources = [str(r) for r in _as_list(statement.get("Resource"))]

        if "*" in actions:
            errors.append(
                f"{source_label}: wildcard Action '*' is not allowed"
            )

        if "*" in resources and not (
            actions and all(a in wildcard_allowed_actions for a in actions)
        ):
            errors.append(
                f"{source_label}: unapproved wildcard Resource '*'"
            )

        if "NotAction" in statement:
            errors.append(f"{source_label}: NotAction is not allowed")

        if "NotResource" in statement:
            errors.append(f"{source_label}: NotResource is not allowed")

        for action in actions:
            for entry in prohibited_prefixes:
                prefix = entry["prefix"]
                if action.lower().startswith(prefix.lower()):
                    errors.append(
                        f"{source_label}: prohibited {entry['category']}: {action}"
                    )


def _check_policy_file(request_dir, filename, prohibited_prefixes, wildcard_allowed_actions, source_label, errors):
    if not filename:
        errors.append(f"{source_label}: missing policy file reference")
        return

    policy_path = os.path.join(request_dir, filename)
    if not os.path.isfile(policy_path):
        errors.append(f"{source_label}: policy file not found: {filename}")
        return

    with open(policy_path, "r", encoding="utf-8") as f:
        raw = f.read()
    try:
        policy_doc = json.loads(raw)
    except json.JSONDecodeError as exc:
        errors.append(f"{source_label}: invalid JSON in {filename}: {exc}")
        return

    _check_policy_document(
        policy_doc, prohibited_prefixes, wildcard_allowed_actions, source_label, errors
    )


def _maybe_run_access_analyzer(request_dir, filenames):
    """Best-effort IAM Access Analyzer policy validation.

    Disabled unless IAM_PLATFORM_ENABLE_ACCESS_ANALYZER=1 is explicitly set.
    Merely having the `aws` CLI on PATH is not sufficient to trigger a real
    network call to AWS -- this machine (or CI) may have live credentials
    configured for an unrelated account, and this validator must never
    contact AWS unless a human has explicitly opted in.
    """
    if os.environ.get("IAM_PLATFORM_ENABLE_ACCESS_ANALYZER") != "1":
        return []

    if shutil.which("aws") is None:
        return []

    warnings = []
    for filename in filenames:
        policy_path = os.path.join(request_dir, filename)
        if not os.path.isfile(policy_path):
            continue
        try:
            proc = subprocess.run(
                [
                    "aws",
                    "accessanalyzer",
                    "validate-policy",
                    "--policy-document",
                    f"file://{policy_path}",
                    "--policy-type",
                    "IDENTITY_POLICY",
                ],
                capture_output=True,
                text=True,
                timeout=15,
            )
            if proc.returncode != 0:
                continue
            findings = json.loads(proc.stdout or "{}").get("findings", [])
            for finding in findings:
                if finding.get("findingType") in ("ERROR", "SECURITY_WARNING"):
                    warnings.append(
                        f"{filename}: Access Analyzer {finding.get('findingType')}: "
                        f"{finding.get('issueCode')}"
                    )
        except Exception:
            # Best-effort only: never let Access Analyzer availability/behavior
            # affect validation results.
            continue
    return warnings


def validate_request(path, guardrails_dir="guardrails", today=None):
    errors = []
    today = today or datetime.date.today()
    request_dir = os.path.dirname(path)

    try:
        request = load_request(path)
    except yaml.YAMLError as exc:
        return [f"invalid YAML in {path}: {exc}"]

    if not isinstance(request, dict):
        return [f"invalid request document in {path}: expected a mapping"]

    allowed_policies_doc = _load_guardrail_yaml(
        guardrails_dir, "allowed-aws-managed-policies.yaml"
    )
    allowed_arns = {
        p["arn"] for p in allowed_policies_doc.get("allowed_policies", [])
    }

    prohibited_doc = _load_guardrail_yaml(guardrails_dir, "prohibited-actions.yaml")
    prohibited_prefixes = prohibited_doc.get("prohibited_prefixes", [])
    wildcard_allowed_actions = set(
        prohibited_doc.get("resource_wildcard_allowed_actions", [])
    )

    account_id = request.get("account_id")
    if not account_id:
        errors.append("missing required field: account_id")
    elif not ACCOUNT_ID_RE.match(str(account_id)):
        errors.append(f"invalid account_id (must be 12 digits): {account_id!r}")

    path_parts = _path_components(path)
    component = path_parts["component"]
    path_account_id = path_parts["account_id"]
    if account_id and str(account_id) != path_account_id:
        errors.append(
            "account_id mismatch: request declares account_id "
            f"{account_id!r} but is stored under account directory "
            f"{path_account_id!r}"
        )

    if not request.get("environment"):
        errors.append("missing required field: environment")

    identity = request.get("identity") or {}
    is_legacy_user = identity.get("type") == "legacy_iam_user"
    is_service_role = identity.get("type") == "aws_service_role"
    is_iam_group = identity.get("type") == "iam_group"
    is_standalone_policy = component == "policies"

    if is_standalone_policy:
        owner = request.get("owner")
        name = request.get("name")
    else:
        owner = identity.get("owner")
        name = identity.get("name")

    if not owner:
        errors.append("missing required field: owner")
    if not name:
        errors.append("missing required field: identity name / policy name")

    if is_legacy_user:
        if not request.get("business_reason"):
            errors.append("missing required field: business_reason (required for legacy_iam_user)")
        if not request.get("exception_ticket"):
            errors.append("missing required field: exception_ticket (required for legacy_iam_user)")

        expires_on = request.get("expires_on")
        if not expires_on:
            errors.append("missing required field: expires_on (required for legacy_iam_user)")
        else:
            try:
                expires_date = datetime.date.fromisoformat(str(expires_on))
                if expires_date < today:
                    errors.append(f"request expired on {expires_on}")
            except ValueError:
                errors.append(f"invalid expires_on date (expected YYYY-MM-DD): {expires_on!r}")

        policy = request.get("policy") or {}
        if policy.get("type") != "custom":
            errors.append("legacy_iam_user requests must declare policy.type: custom")
        _check_policy_file(
            request_dir,
            policy.get("file"),
            prohibited_prefixes,
            wildcard_allowed_actions,
            f"{path}:policy",
            errors,
        )

    elif is_service_role:
        trust = request.get("trust") or {}
        if not trust.get("service"):
            errors.append("missing required field: trust.service (required for aws_service_role)")

        policies = request.get("policies") or {}
        aws_managed = _as_list(policies.get("aws_managed"))
        custom = _as_list(policies.get("custom"))

        for arn in aws_managed:
            if arn not in allowed_arns:
                errors.append(f"unknown AWS-managed policy ARN (not in allow-list): {arn}")

        for entry in custom:
            if not isinstance(entry, dict) or not entry.get("name"):
                errors.append("each custom policy entry requires a name")
            _check_policy_file(
                request_dir,
                (entry or {}).get("file"),
                prohibited_prefixes,
                wildcard_allowed_actions,
                f"{path}:policies.custom[{(entry or {}).get('name', '?')}]",
                errors,
            )

        if not aws_managed and not custom:
            errors.append("role requests must declare at least one of policies.aws_managed or policies.custom")

        create_instance_profile = request.get("create_instance_profile")
        if create_instance_profile is not None and not isinstance(create_instance_profile, bool):
            errors.append("create_instance_profile must be a boolean")

    elif is_iam_group:
        policies = request.get("policies") or {}
        aws_managed = _as_list(policies.get("aws_managed"))
        custom = _as_list(policies.get("custom"))

        for arn in aws_managed:
            if arn not in allowed_arns:
                errors.append(f"unknown AWS-managed policy ARN (not in allow-list): {arn}")

        for entry in custom:
            if not isinstance(entry, dict) or not entry.get("name"):
                errors.append("each custom policy entry requires a name")
            _check_policy_file(
                request_dir,
                (entry or {}).get("file"),
                prohibited_prefixes,
                wildcard_allowed_actions,
                f"{path}:policies.custom[{(entry or {}).get('name', '?')}]",
                errors,
            )

        members = request.get("members")
        if members is not None:
            if not isinstance(members, list) or not all(isinstance(m, str) for m in members):
                errors.append("members must be a list of IAM user name strings")

    elif is_standalone_policy:
        policy_file = request.get("file") or (request.get("policy") or {}).get("file")
        _check_policy_file(
            request_dir,
            policy_file,
            prohibited_prefixes,
            wildcard_allowed_actions,
            f"{path}:file",
            errors,
        )

    else:
        errors.append(
            f"unrecognized identity.type/component combination: identity.type={identity.get('type')!r}, component={component!r}"
        )

    return errors


def main(argv):
    guardrails_dir = "guardrails"
    paths = [a for a in argv if a != "--"]
    if not paths:
        paths = discover_requests("requests")

    all_ok = True
    for path in paths:
        errors = validate_request(path, guardrails_dir=guardrails_dir)
        if errors:
            all_ok = False
            for err in errors:
                print(f"ERROR {path}: {err}")
        else:
            print(f"OK {path}")

        # Opt-in only (IAM_PLATFORM_ENABLE_ACCESS_ANALYZER=1) -- never runs
        # by default, so merely having the AWS CLI installed and configured
        # never causes a real network call to AWS. See
        # _maybe_run_access_analyzer for why.
        request_dir = os.path.dirname(path)
        json_filenames = [f for f in os.listdir(request_dir) if f.endswith(".json")]
        for warning in _maybe_run_access_analyzer(request_dir, json_filenames):
            print(f"WARN {path}: {warning}")

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
