---
name: new-iam-request
description: Use when authoring a new IAM user, role, standalone policy, or group request in this repo from an application team's ticket -- creates the request.yaml (and policy JSON) under the right requests/ path and gets it guardrail-clean before a PR.
---

# New IAM Request

## Overview

In this repo, application teams never touch `requests/` directly -- they
file a ticket, and the platform team (you) writes the `request.yaml` from
it. This skill is that workflow: scaffold, fill in from the ticket, verify
completeness, validate against guardrails, done.

## When to use

- A ticket asks for a new legacy IAM user, service role, standalone
  policy, or group in some AWS account.
- You're about to hand-write a `request.yaml` from scratch -- use the
  scaffolder instead so the path and skeleton fields are never wrong.

## Workflow

1. **Identify the four things every request needs**: `component`
   (`users` / `roles` / `policies` / `groups`), `environment` (`prod` /
   `dev`), `account_id` (12 digits), `name` (the identity/policy name).

2. **Scaffold it**:
   ```bash
   python3 scripts/scaffold_request.py --component roles \
     --environment prod --account-id <account_id> --name <name>
   ```
   This creates `requests/<environment>/<account_id>/<component>/<name>/`
   with a `request.yaml` skeleton and a placeholder policy JSON, both full
   of `TODO` markers. It refuses to overwrite an existing directory.

3. **Fill in every `TODO` from the ticket** -- owner, business
   justification (users only), trust service (roles only), and the actual
   policy statements. Scope `Resource` to specific ARNs; never write
   `Action: "*"` or `Resource: "*"`. See
   [docs/validation-rules.md](../../docs/validation-rules.md) for the
   full guardrail rule list and the AWS-managed-policy allow-list.

4. **Confirm no `TODO` remains** -- `grep -rn TODO requests/<...>/<name>/`.
   **The guardrail validator does not check this.** A file full of
   `TODO-owner@example.com` and `"Action": "TODO:Action"` passes it
   silently (verified: neither is a wildcard, a `NotAction`, or a
   prohibited prefix, so nothing flags it). Passing validation is not the
   same as being done.

5. **Validate**:
   ```bash
   python3 scripts/validate_requests.py requests/<environment>/<account_id>/<component>/<name>/request.yaml
   ```
   Fix and re-run until it prints `OK`.

6. **If this is a new account** (no `live/<environment>/<account_id>/`
   yet), see [docs/add-new-account.md](../../docs/add-new-account.md)
   before opening the PR -- the Terragrunt unit needs to exist for the
   plan workflow to pick this request up.

7. Open the PR. `scripts/changed_targets.py` will scope the plan to
   exactly this account/component.

## Common mistakes

| Mistake | Fix |
|---|---|
| Leaving a `TODO` in owner/policy fields because validation passed | Grep for `TODO` explicitly -- step 4 above -- before treating this as done |
| Writing `Resource: "*"` because scoping felt tedious | Look up the real ARN. If the action genuinely has no resource-level scoping, that's a `guardrails/prohibited-actions.yaml` allow-list decision for the platform team, not something to work around in one request |
| Using an AWS-managed policy not on `guardrails/allowed-aws-managed-policies.yaml` | Either use a custom policy scoped to what's actually needed, or add the ARN to the allow-list first (separate PR, since `guardrails/` changes require controlled rollout) |
| Real account IDs or hostnames in anything meant to be an illustrative example | Use a placeholder like `999999999999` -- this repo's docs/examples should never carry a real account number |
