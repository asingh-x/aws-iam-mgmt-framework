# Bootstrap: OrgIAMProvisioner_DoNotDelete via CloudFormation StackSet

`iam-provisioner.yaml` creates, in one member account:

- `org-mandatory-permissions-boundary` -- the managed policy every
  `modules/iam-user` / `modules/iam-role` call references.
- `OrgIAMProvisioner_DoNotDelete` -- the role Terragrunt's `live/root.hcl` generates an
  `assume_role` block for. Its own permissions are scoped to IAM
  provisioning (create/attach/tag role, user, policy, instance profile),
  it cannot modify its own trust policy or the boundary policy, it cannot
  attach `AdministratorAccess`/`IAMFullAccess`, and it can only create a
  user/role that already carries the mandatory boundary.

## Architecture this assumes

```
GitHub Actions --(OIDC)--> hub account role (github-actions-iam-platform)
                                   |
                                   | sts:AssumeRole (TrustedPrincipalArn below)
                                   v
                    OrgIAMProvisioner_DoNotDelete in EVERY member account
                    (created here, once per account, automatically)
```

The hub account role is out of scope for this template (it's a one-time
manual/Terraform setup in whichever account runs your CI/CD), but its ARN
is exactly what you pass as `TrustedPrincipalArn` below.

## Deploying to every account automatically (new accounts included)

This is a StackSet with **service-managed permissions**, targeted at your
Organization's root or specific OUs, so it deploys to every account in
scope today and automatically deploys again whenever a new account joins
one of those OUs -- no per-account manual step.

Run this from the AWS Organizations **management account** (or a
delegated administrator account), once:

```bash
# One-time per org: allow StackSets to use service-managed permissions.
aws organizations enable-aws-service-access \
  --service-principal member.org.stacksets.cloudformation.amazonaws.com

aws cloudformation create-stack-set \
  --stack-set-name iam-provisioner \
  --template-body file://iam-provisioner.yaml \
  --permission-model SERVICE_MANAGED \
  --auto-deployment Enabled=true,RetainStacksOnAccountRemoval=false \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=TrustedPrincipalArn,ParameterValue=arn:aws:iam::<hub-account-id>:role/github-actions-iam-platform

aws cloudformation create-stack-instances \
  --stack-set-name iam-provisioner \
  --deployment-targets OrganizationalUnitIds=<ou-id-1>,<ou-id-2> \
  --regions us-east-1
```

`OrganizationalUnitIds` can be your org's root ID to target every account.
IAM is global, so `--regions` just needs one region for CloudFormation to
run the stack in -- it doesn't scope which IAM resources get created.

## Adding one account manually (no StackSet, e.g. for testing)

```bash
aws cloudformation create-stack \
  --stack-name iam-provisioner \
  --template-body file://iam-provisioner.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=TrustedPrincipalArn,ParameterValue=arn:aws:iam::<hub-account-id>:role/github-actions-iam-platform
```

## Local checks (no AWS contact)

```bash
python3 -c "import yaml; yaml.safe_load(open('iam-provisioner.yaml'))"  # with CFN intrinsic tags registered
cfn-lint iam-provisioner.yaml   # if installed
```

`aws cloudformation validate-template` also works but makes a real
(read-only) call to AWS -- run it deliberately, not as part of routine
local validation.
