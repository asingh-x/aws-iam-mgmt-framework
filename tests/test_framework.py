import datetime
import os
import unittest

from scripts import validate_requests
from scripts import changed_targets

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")
REPO_ROOT = os.path.dirname(os.path.dirname(__file__))
GUARDRAILS = os.path.join(REPO_ROOT, "guardrails")
TODAY = datetime.date(2026, 9, 3)


def fixture_request(*parts):
    return os.path.join(FIXTURES, *parts, "request.yaml")


class TestValidateRequests(unittest.TestCase):
    def validate(self, path):
        return validate_requests.validate_request(
            path, guardrails_dir=GUARDRAILS, today=TODAY
        )

    # 1. Valid IAM user with a custom policy.
    def test_valid_iam_user_with_custom_policy(self):
        path = fixture_request(
            "valid_user", "production", "111111111111", "users", "reporting-app"
        )
        self.assertEqual(self.validate(path), [])

    # 2. Valid standalone custom managed policy.
    def test_valid_standalone_custom_policy(self):
        path = fixture_request(
            "valid_policy",
            "production",
            "111111111111",
            "policies",
            "reporting-s3-read",
        )
        self.assertEqual(self.validate(path), [])

    # 3. Valid role with an AWS-managed policy.
    def test_valid_role_with_aws_managed_policy(self):
        path = fixture_request(
            "valid_role_aws_managed",
            "production",
            "111111111111",
            "roles",
            "test-role",
        )
        self.assertEqual(self.validate(path), [])

    # 4. Valid role with AWS-managed and custom policies.
    def test_valid_role_with_aws_managed_and_custom_policies(self):
        path = fixture_request(
            "valid_role_mixed",
            "production",
            "111111111111",
            "roles",
            "reporting-lambda",
        )
        self.assertEqual(self.validate(path), [])

    # 5. Invalid wildcard action.
    def test_invalid_wildcard_action(self):
        path = fixture_request(
            "invalid_wildcard_action", "production", "111111111111", "users", "bad-app"
        )
        errors = self.validate(path)
        self.assertTrue(any("wildcard Action" in e for e in errors), errors)

    # 6. Invalid wildcard resource.
    def test_invalid_wildcard_resource(self):
        path = fixture_request(
            "invalid_wildcard_resource",
            "production",
            "111111111111",
            "users",
            "bad-app",
        )
        errors = self.validate(path)
        self.assertTrue(any("wildcard Resource" in e for e in errors), errors)

    # 7. Prohibited IAM administration action.
    def test_prohibited_iam_administration_action(self):
        path = fixture_request(
            "prohibited_iam_admin", "production", "111111111111", "users", "bad-app"
        )
        errors = self.validate(path)
        self.assertTrue(
            any("IAM administration actions" in e for e in errors), errors
        )

    # 8. Missing owner.
    def test_missing_owner(self):
        path = fixture_request(
            "missing_owner", "production", "111111111111", "roles", "bad-role"
        )
        errors = self.validate(path)
        self.assertTrue(any("owner" in e.lower() for e in errors), errors)

    # 9. Missing IAM-user exception ticket.
    def test_missing_exception_ticket(self):
        path = fixture_request(
            "missing_exception_ticket",
            "production",
            "111111111111",
            "users",
            "bad-app",
        )
        errors = self.validate(path)
        self.assertTrue(any("exception_ticket" in e for e in errors), errors)

    # 10. Expired IAM-user request.
    def test_expired_request(self):
        path = fixture_request(
            "expired_request", "production", "111111111111", "users", "bad-app"
        )
        errors = self.validate(path)
        self.assertTrue(any("expired" in e.lower() for e in errors), errors)

    # 11. Unknown AWS-managed policy.
    def test_unknown_aws_managed_policy(self):
        path = fixture_request(
            "unknown_managed_policy",
            "production",
            "111111111111",
            "roles",
            "bad-role",
        )
        errors = self.validate(path)
        self.assertTrue(
            any("AdministratorAccess" in e for e in errors), errors
        )

    # 12. Account ID/path mismatch.
    def test_account_id_path_mismatch(self):
        path = fixture_request(
            "account_mismatch", "production", "222222222222", "users", "bad-app"
        )
        errors = self.validate(path)
        self.assertTrue(any("mismatch" in e.lower() for e in errors), errors)

    # 13. Missing custom policy file.
    def test_missing_custom_policy_file(self):
        path = fixture_request(
            "missing_policy_file", "production", "111111111111", "users", "bad-app"
        )
        errors = self.validate(path)
        self.assertTrue(
            any("does-not-exist.json" in e for e in errors), errors
        )

    # 14. Invalid policy JSON.
    def test_invalid_policy_json(self):
        path = fixture_request(
            "invalid_json", "production", "111111111111", "users", "bad-app"
        )
        errors = self.validate(path)
        self.assertTrue(any("invalid JSON" in e for e in errors), errors)

    # Bonus: valid IAM group with AWS-managed + custom policy + members.
    def test_valid_iam_group(self):
        path = fixture_request(
            "valid_group", "production", "111111111111", "groups", "reporting-group"
        )
        self.assertEqual(self.validate(path), [])


class TestChangedTargets(unittest.TestCase):
    # 15. Account A change selects only Account A.
    def test_account_a_change_selects_only_account_a(self):
        result = changed_targets.classify_paths(
            ["requests/production/111111111111/users/reporting-app/request.yaml"],
            requests_root=os.path.join(REPO_ROOT, "requests"),
        )
        self.assertEqual(
            result["targets"],
            [{"environment": "production", "account_id": "111111111111"}],
        )

    # 16. Account B is not selected by an Account A change.
    def test_account_b_not_selected_by_account_a_change(self):
        result = changed_targets.classify_paths(
            ["requests/production/111111111111/users/reporting-app/request.yaml"],
            requests_root=os.path.join(REPO_ROOT, "requests"),
        )
        self.assertFalse(
            any(t["account_id"] == "222222222222" for t in result["targets"])
        )

    # 17. Multiple changed files for Account A are deduplicated.
    def test_multiple_files_same_account_deduplicated(self):
        result = changed_targets.classify_paths(
            [
                "requests/production/111111111111/roles/reporting-lambda/request.yaml",
                "requests/production/111111111111/roles/reporting-lambda/custom-policy.json",
            ],
            requests_root=os.path.join(REPO_ROOT, "requests"),
        )
        self.assertEqual(
            result["targets"],
            [{"environment": "production", "account_id": "111111111111"}],
        )

    # Bonus: one account's state file covers every component (users, roles,
    # policies, groups), so changes across different components of the
    # SAME account also collapse into a single target -- not one per
    # component.
    def test_multiple_components_same_account_deduplicated(self):
        result = changed_targets.classify_paths(
            [
                "requests/production/111111111111/roles/reporting-lambda/request.yaml",
                "requests/production/111111111111/users/reporting-app/request.yaml",
                "requests/production/111111111111/policies/reporting-s3-read/request.yaml",
            ],
            requests_root=os.path.join(REPO_ROOT, "requests"),
        )
        self.assertEqual(
            result["targets"],
            [{"environment": "production", "account_id": "111111111111"}],
        )

    # 18. Module changes require controlled rollout.
    def test_module_change_requires_controlled_rollout(self):
        result = changed_targets.classify_paths(["modules/iam-role/main.tf"])
        self.assertTrue(result["controlled_rollout_required"])
        self.assertEqual(result["targets"], [])
        self.assertIn("rollout manifest", result["message"])

    def test_guardrails_change_requires_controlled_rollout(self):
        result = changed_targets.classify_paths(
            ["guardrails/allowed-aws-managed-policies.yaml"]
        )
        self.assertTrue(result["controlled_rollout_required"])
        self.assertEqual(result["targets"], [])

    # Bonus (spec "Required behavior", not part of the numbered 1-18 list):
    # changes under requests/common/ may span multiple accounts. Uses an
    # isolated fixture tree (not the live requests/ tree) so this test
    # doesn't depend on which real accounts happen to exist on disk.
    def test_common_change_can_span_multiple_accounts(self):
        result = changed_targets.classify_paths(
            ["requests/common/roles/shared-tags.yaml"],
            requests_root=os.path.join(FIXTURES, "common_fanout"),
        )
        account_ids = {t["account_id"] for t in result["targets"]}
        self.assertEqual(account_ids, {"111111111111", "222222222222"})

    def test_module_change_with_rollout_manifest_is_scoped(self):
        manifest_path = os.path.join(FIXTURES, "rollout_manifest.json")
        result = changed_targets.classify_paths(
            ["modules/iam-role/main.tf"], rollout_manifest=manifest_path
        )
        self.assertFalse(result["controlled_rollout_required"])
        self.assertEqual(
            result["targets"],
            [{"environment": "production", "account_id": "111111111111"}],
        )


if __name__ == "__main__":
    unittest.main()
