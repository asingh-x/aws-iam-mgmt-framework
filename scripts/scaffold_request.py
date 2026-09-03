"""Scaffold a new, skeleton IAM request under requests/.

Mechanical helper only: creates the directory and a request.yaml (plus a
placeholder policy JSON where the component needs one) with TODO markers
for every field that requires real judgment (owner, business reason,
actual policy statements, etc). It deliberately does NOT try to guess
permissions or business justification -- fill those in from the ticket,
then run scripts/validate_requests.py before opening a PR.
"""

import argparse
import os
import sys

REQUESTS_ROOT = os.path.join(os.path.dirname(os.path.dirname(__file__)), "requests")

SKELETONS = {
    "users": """account_id: "{account_id}"
environment: {environment}

identity:
  type: legacy_iam_user
  name: {name}
  owner: TODO-owner@example.com

business_reason: "TODO: why this legacy user cannot assume a role"
exception_ticket: "TODO-TICKET-ID"
expires_on: "TODO-YYYY-MM-DD"

policy:
  type: custom
  file: custom-policy.json

credential:
  rotation_days: 60
  delivery: secrets_manager
""",
    "roles": """account_id: "{account_id}"
environment: {environment}

identity:
  type: aws_service_role
  name: {name}
  owner: TODO-owner@example.com

trust:
  service: TODO-service.amazonaws.com

policies:
  aws_managed: []
  custom:
    - name: TODO-PolicyName
      file: custom-policy.json

create_instance_profile: false
""",
    "policies": """account_id: "{account_id}"
environment: {environment}

name: TODO-PolicyName
owner: TODO-owner@example.com
description: "TODO: what this policy grants and why"

file: policy.json
""",
    "groups": """account_id: "{account_id}"
environment: {environment}

identity:
  type: iam_group
  name: {name}
  owner: TODO-owner@example.com

policies:
  aws_managed: []
  custom:
    - name: TODO-PolicyName
      file: custom-policy.json

members: []
""",
}

POLICY_FILENAME = {
    "users": "custom-policy.json",
    "roles": "custom-policy.json",
    "policies": "policy.json",
    "groups": "custom-policy.json",
}

POLICY_SKELETON = """{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TODO",
      "Effect": "Allow",
      "Action": "TODO:Action",
      "Resource": "arn:aws:TODO"
    }
  ]
}
"""


def scaffold(component, environment, account_id, name, requests_root=REQUESTS_ROOT):
    if component not in SKELETONS:
        raise ValueError(f"unknown component: {component!r} (expected one of {list(SKELETONS)})")

    request_dir = os.path.join(requests_root, environment, account_id, component, name)
    if os.path.exists(request_dir):
        raise FileExistsError(f"request directory already exists: {request_dir}")

    os.makedirs(request_dir)

    request_path = os.path.join(request_dir, "request.yaml")
    with open(request_path, "w", encoding="utf-8") as f:
        f.write(SKELETONS[component].format(account_id=account_id, environment=environment, name=name))

    policy_path = os.path.join(request_dir, POLICY_FILENAME[component])
    with open(policy_path, "w", encoding="utf-8") as f:
        f.write(POLICY_SKELETON)

    return request_dir


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--component", required=True, choices=sorted(SKELETONS))
    parser.add_argument("--environment", required=True)
    parser.add_argument("--account-id", required=True)
    parser.add_argument("--name", required=True)
    args = parser.parse_args(argv)

    try:
        request_dir = scaffold(args.component, args.environment, args.account_id, args.name)
    except (ValueError, FileExistsError) as exc:
        print(f"ERROR: {exc}")
        return 1

    print(f"Scaffolded {request_dir}")
    print("Next:")
    print("  1. Fill in every TODO with real values from the ticket.")
    print(f"  2. Confirm none remain: grep -rn TODO {request_dir}")
    print("     (the validator checks guardrails, not completeness -- a")
    print("      file full of TODOs can still pass it silently.)")
    print(f"  3. python3 scripts/validate_requests.py {request_dir}/request.yaml")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
