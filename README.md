# Proposed Infrastructure Project for CPA QualityPro

This project deploys application infrastructure on Amazon EKS: networking, a Kubernetes cluster, HTTPS ingress, observability, and application access to AWS services. Each deployment manages one shared ALB, EKS cluster, Istio installation and Argo CD installation, plus both `stage` and `prod` application namespaces with separate backend/frontend permissions. One root module calls the reusable `modules/qualitypro` module; a single HCP Terraform workspace/state owns S3, cluster infrastructure and one private RDS PostgreSQL instance. Stage/prod use the shared cluster and may connect to the same PostgreSQL instance with separately created database users.

```text
Internet → application domain → public ALB → Istio ingress gateway
```

## Components Deployed

- A VPC with public/private subnets across two Availability Zones, an Internet Gateway, NAT gateways, routing, and an S3 Gateway VPC Endpoint.
- EKS with a Managed Node Group in one private subnet in the explicitly selected `node_availability_zone`, CoreDNS, kube-proxy, VPC CNI, and the EKS Pod Identity Agent. Both worker nodes share that AZ; an AZ outage affects all workers. VPC, EKS control plane and ALB retain subnets across two AZs.
- Istio: base components, istiod, and an ingress gateway with a NodePort Service.
- The AWS Load Balancer Controller and an Ingress that creates a public ALB with HTTPS and HTTP-to-HTTPS redirection.
- Both `stage` and `prod` application namespaces with Istio injection, backend/frontend ServiceAccounts, and separate IAM roles through EKS Pod Identity.
- One S3 bucket per application namespace, plus AppSync Event APIs, SNS topics, SQS queues, and subscriptions from shared base names, prefixed with `stage-` or `prod-`. An empty SNS topic list disables messaging in both environments.
- CloudWatch Observability for metrics and logs, plus EKS control plane logging.
- External Secrets Operator with CRDs in the dedicated `external-secrets` namespace, using EKS Pod Identity to read AWS Secrets Manager.
- Self-hosted Argo CD installed by Helm, behind the shared ALB and Istio ingress gateway, with local cluster registration, and Kubernetes RBAC for application deployment.
- One encrypted, private RDS PostgreSQL instance in the cluster VPC, requiring TLS and password authentication. Terraform creates no application database or application SQL users; the built-in `postgres` database is available for administration. RDS generates the administrator password in Secrets Manager.

## Project Structure and HCP Terraform Setup

```text
main.tf                    # Calls module.qualitypro
providers.tf               # AWS, Kubernetes and Helm provider configuration
variables.tf               # Deployment inputs
outputs.tf                 # Forwards module outputs
versions.tf                # Terraform/provider requirements
.terraform.lock.hcl        # Shared provider selections
terraform.tfvars.example   # All deployment settings in one file
tests/                     # Root module integration tests
modules/qualitypro/         # Reusable infrastructure implementation and tests
```

The repository root is the only deployment entry point. `modules/qualitypro` contains the S3, VPC/EKS, Kubernetes/Helm and RDS resources. Both `stage` and `prod` always share one cluster and one PostgreSQL instance; there is no separate-environment deployment layer. The module has no provider configurations or backend of its own: callers provide AWS, Kubernetes, Helm and time providers, as shown in `main.tf` and `providers.tf`.

Internal dependencies use direct Terraform references: backend IAM policies reference the created S3 bucket ARNs, and RDS references the VPC private subnets and EKS node security group. Terraform orders creation and destruction through this graph. No SSM parameter needs to exist before planning. The module still publishes non-secret storage, network and database metadata at `/qualitypro/<project_name>/{storage,network,database}` for external tooling; it does not read those parameters back.

### Fresh Deployment

1. Create **one new VCS-backed HCP Terraform workspace** connected to this repository and branch. Leave **Terraform Working Directory empty** so execution starts at the repository root. Commit the root files, `modules/qualitypro`, and the root `.terraform.lock.hcl` together.
2. Choose Terraform 1.9 or newer, below 2.0, with Remote execution or an HCP agent. Supply AWS authentication separately, including the workspace's OIDC trust when using dynamic credentials.
3. Use the root `terraform.tfvars.example` as a reference and enter all required values in this workspace's **Variables → Terraform variables**. Strings use HCL disabled; lists, numbers, booleans and `null` use HCL enabled. Actual `terraform.tfvars` files are ignored by Git and are not uploaded by a VCS-backed run. The example file is not loaded automatically.
4. Prepare the ACM certificate and domains below. The runner needs AWS CLI for `aws eks get-token`, network access to the EKS API allowed by `cluster_endpoint_public_access_cidrs`, and permissions to manage all resources in this deployment: S3, EC2/VPC, EKS, IAM, AppSync, SNS/SQS, CloudWatch, RDS and the three published SSM parameters. RDS engine/class availability queries and management of its Secrets Manager administrator secret must also be allowed. Customer-managed KMS keys need their corresponding permissions.
5. Queue **Plan → review → Apply** in this workspace. Terraform creates S3, the shared VPC/EKS stack, Kubernetes components and private PostgreSQL using their resource dependencies. There are no separate storage/infrastructure/database runs to sequence. After Apply, use `alb_dns_name`, `argocd_server_url`, `database_url` and `master_user_secret_arn` from the same workspace's outputs.

The Kubernetes and Helm providers receive the new cluster endpoint and CA from module outputs. They require a reachable, authenticated EKS API when managing in-cluster resources. Mocked tests validate the dependency graph and configuration but do not establish live API readiness.

For another AWS account, reuse the same module with that account's runner credentials and suitable input values, including its ACM certificate, cluster name and S3 base name. The ACM certificate must be in `aws_region`.

See [HCP workspace settings](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/settings), [HCP variables](https://developer.hashicorp.com/terraform/cloud-docs/variables), and [providers within modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers).

## Existing Resources to Prepare

### Domain and ACM Certificate

Set `domain_name` to a list of hostnames or wildcard hostnames that the shared ALB should forward to Istio, for example `["*.example.com"]` or `["app.example.com", "argocd.example.com", "api.example.com"]`. Exact and wildcard entries can be combined. Access to the DNS provider is required for certificate validation and subsequent CNAME configuration.

Use wildcards only as the first label, such as `*.example.com`. Kubernetes Ingress wildcard hosts cover one subdomain level. The ACM wildcard certificate `*.example.com` covers `stage.example.com`, `prod.example.com`, and `argocd.example.com`, but not `example.com` or `api.stage.example.com`; add explicit entries or another wildcard and matching certificate coverage for those names. Configure DNS for the selected hostnames (or a wildcard DNS record) and matching Istio Gateway/VirtualService routes separately. See [Kubernetes Ingress wildcard hosts](https://kubernetes.io/docs/concepts/services-networking/ingress/#hostname-wildcards) and [ALB wildcard certificates](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/https-listener-certificates.html).

Prepare an issued ACM certificate covering every hostname in this list and supply its ARN in `acm_certificate_arn`. The certificate must be in the same region as the ALB. Validation checks the ARN against `aws_region`.

The project does not issue certificates or create DNS records. After deployment, use the `alb_dns_name` output as the CNAME target for the selected subdomain.

### Cognito User Pool

Configure Cognito in each application's deployment using `COGNITO_POOL_ID`, the pool's region, and `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` supplied from Kubernetes Secrets. The Cognito client must explicitly use these credentials and the pool's region. Cognito may be in a different region from EKS. The IAM identity owning those credentials must have the required Cognito permissions on the actual User Pool ARN.

Terraform does not create or modify Cognito pools, manage their credentials, or grant Cognito permissions to application Pod Identity roles. User sign-in settings and application client integration remain outside the project's scope.

If `AWS_REGION` supplies the Cognito region, set it to the pool's region. AWS credentials supplied through environment variables can take precedence over Pod Identity in the SDK's default credential chain. To keep S3/SNS/SQS clients using Pod Identity in the same process, configure those clients with the container credential provider and the infrastructure region explicitly. Terraform cannot select credential providers inside application code. See [EKS Pod Identity SDK credential selection](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-minimum-sdk.html) and [AWS credential providers](https://docs.aws.amazon.com/sdkref/latest/guide/standardized-credentials.html).

### Argo CD Domain

Set `argocd_domain_name` to a concrete hostname (for example `argocd.example.com`) for the public Argo CD URL and cover it with an exact or wildcard entry in `domain_name`. The ALB forwards hostnames matching these entries. The existing `acm_certificate_arn` must cover the selected hostnames. Point the Argo CD hostname to the shared `alb_dns_name` output and configure your Istio Gateway/VirtualService for this hostname. The Helm installation enables the local `admin` account.

## Parameters to Configure Before Deployment

Use Terraform 1.9 or newer. Both `stage` and `prod`, their S3 buckets and the shared PostgreSQL instance are managed in one workspace/state.

The root `terraform.tfvars.example` contains all deployment settings. Local `terraform.tfvars` files are ignored by Git and must not be assumed present in a VCS-backed HCP run. Copy the required values into the single workspace's **Variables → Terraform variables**. Local validation and mocked tests are documented below. Shared application settings are flat root variables; there is no nested `application_namespaces` input to duplicate per environment.

Strings in the table are entered without surrounding quotes with HCL disabled. Enable HCL for lists, booleans, numbers, and `null`, entering only the value, not `key = value`. See [HCP Terraform variable values](https://developer.hashicorp.com/terraform/cloud-docs/variables/managing-variables).

Every variable without a `default` is required and uses `nullable = false`: supply each required value before planning. Variables with defaults remain optional. `node_instance_type` accepts one string, for example `c7i-flex.large` with HCL disabled; Terraform wraps it in a single-element list for the EKS module.

### Common variables

| Variable key | Example value in HCP Terraform | HCL | Required / default |
| --- | --- | --- | --- |
| `aws_region` | `us-east-1` | No | Required; region for the entire deployment |
| `project_name` | `my-cluster` | No | Required; stable deployment identifier, 1-64 letters/digits/underscores/hyphens |

### Storage variables

| Variable key | Example value in HCP Terraform | HCL | Required / default |
| --- | --- | --- | --- |
| `s3_bucket_name` | `qualitypro-docs` | No | Required; shared base name |
| `s3_force_destroy` | `false` | Yes | Optional; `false`; allow deleting bucket contents during destroy |

### Infrastructure variables

| Variable key | Example value in HCP Terraform | HCL | Required / default |
| --- | --- | --- | --- |
| `domain_name` | `["*.example.com"]` | Yes | Required; list of exact or wildcard hostnames |
| `argocd_domain_name` | `argocd.example.com` | No | Required |
| `acm_certificate_arn` | `arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000` | No | Required |
| `appsync_event_api_name` | `["events", "other"]` | Yes | Required; non-empty shared list |
| `backend_sns_topic_names` | `["notifications", "audit"]` | Yes | Required; no default; `[]` disables SNS/SQS |
| `appsync_event_namespace_name` | `events` | No | Optional; `events` |
| `cluster_name` | `my-cluster` | No | Required |
| `kubernetes_version` | `1.36` | No | Required |
| `vpc_cidr` | `10.0.0.0/16` | No | Optional; `10.0.0.0/16` |
| `public_subnet_cidrs` | `["10.0.0.0/24", "10.0.1.0/24"]` | Yes | Optional; shown value |
| `private_subnet_cidrs` | `["10.0.10.0/24", "10.0.11.0/24"]` | Yes | Optional; shown value |
| `nat_gateway_per_az` | `true` | Yes | Optional; `true` |
| `cluster_endpoint_public_access_cidrs` | `["103.0.13.10/32"]` | Yes | Optional; `["0.0.0.0/0"]`; set trusted CIDRs |
| `node_instance_type` | `c7i-flex.large` | No | Required; no default |
| `node_availability_zone` | `us-east-1a` | No | Required; available standard AZ in `aws_region`; all workers use this AZ |
| `node_capacity_type` | `ON_DEMAND` | No | Optional; `ON_DEMAND` |
| `node_min_size` | `2` | Yes | Required |
| `node_max_size` | `2` | Yes | Required |
| `node_desired_size` | `2` | Yes | Required |
| `cloudwatch_log_retention_days` | `30` | Yes | Optional; `30` |
| `cloudwatch_addon_version` | `null` | Yes | Optional; `null` selects latest compatible build |
| `external_secrets_secret_arns` | `["arn:aws:secretsmanager:us-east-1:123456789012:secret:stage/*", "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/*"]` | Yes | Optional; `[]` grants both namespace prefixes |
| `external_secrets_kms_key_arns` | `["arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"]` | Yes | Optional; `[]` |

### Database variables

There is no `db_name` or password input. RDS creates its built-in `postgres` database, while application databases/users are created later through SQL. The instance class and exact engine version are checked against regional AWS availability during plan; `17.10` is an example, not a guarantee for every region/class. The parameter group family is selected from the engine metadata automatically.

| Variable key | Example value in HCP Terraform | HCL | Required / default |
| --- | --- | --- | --- |
| `db_engine_version` | `17.10` | No | Required; exact available PostgreSQL minor version |
| `db_instance_class` | `db.t4g.micro` | No | Required; no default |
| `db_identifier` | `my-cluster-postgres` | No | Optional; derived from the project identifier |
| `db_master_username` | `postgres` | No | Optional; `postgres` |
| `db_port` | `5432` | Yes | Optional; `5432` |
| `db_allocated_storage` | `20` | Yes | Optional; `20` GiB, subject to the selected AWS configuration |
| `db_max_allocated_storage` | `100` | Yes | Optional; `100` GiB; `0` disables autoscaling, otherwise at least 10% above initial storage |
| `db_storage_type` | `gp3` | No | Optional; `gp3`; supports `gp2` or `gp3` |
| `db_kms_key_arn` | `null` | Yes | Optional; null uses the AWS-managed RDS storage key |
| `db_multi_az` | `false` | Yes | Optional; `false`, must be supported by the selected class |
| `db_backup_retention_days` | `7` | Yes | Optional; `7`; `0` disables automated backups |
| `db_backup_window` | `01:00-02:00` | No | Optional; AWS selects a window when null; UTC, must not overlap maintenance |
| `db_maintenance_window` | `sun:03:00-sun:04:00` | No | Optional; AWS selects a window when null; UTC |
| `db_deletion_protection` | `true` | Yes | Optional; `true`; apply false before intentional destruction |
| `db_skip_final_snapshot` | `false` | Yes | Optional; `false` |
| `db_final_snapshot_identifier` | `my-cluster-postgres-final-20261012` | No | Optional; `<db_identifier>-final`; choose a unique name if that snapshot already exists |
| `db_apply_immediately` | `false` | Yes | Optional; `false`; immediate changes may restart RDS |
| `db_auto_minor_version_upgrade` | `true` | Yes | Optional; `true` |
| `db_allow_major_version_upgrade` | `false` | Yes | Optional; `false`; explicit opt-in for a major upgrade |

Storage is always encrypted, public accessibility and IAM database authentication are always disabled, and the parameter group sets `rds.force_ssl = 1`. Old major versions are not automatically enrolled in paid RDS Extended Support. See [RDS instance settings](https://registry.terraform.io/providers/hashicorp/aws/6.52.0/docs/resources/db_instance) and [PostgreSQL version availability](https://docs.aws.amazon.com/AmazonRDS/latest/PostgreSQLReleaseNotes/postgresql-versions.html).

Allocate sufficient node capacity for system components and applications in both environments. EKS API access must allow the network from which Terraform runs. Configure AWS authentication for the runner separately.

The shared application values are entered once in the root configuration:

```hcl
backend_sns_topic_names = ["notifications", "audit"]
appsync_event_api_name  = ["events", "other"]
```

Set `s3_bucket_name = "qualitypro-docs"` once. The module creates the following namespace-specific resources plus one shared PostgreSQL instance:

| Resource | stage | prod |
| --- | --- | --- |
| Kubernetes namespace | `stage` | `prod` |
| S3 bucket | `stage-qualitypro-docs-123456789012-us-east-1` | `prod-qualitypro-docs-123456789012-us-east-1` |
| SNS topics | `stage-notifications`, `stage-audit` | `prod-notifications`, `prod-audit` |
| SQS queues | `stage-notifications-sub`, `stage-audit-sub` | `prod-notifications-sub`, `prod-audit-sub` |
| AppSync APIs | `stage-events`, `stage-other` | `prod-events`, `prod-other` |

S3 bucket names use `<namespace>-<s3_bucket_name>-<account-id>-<region>`. Terraform appends the current account/region suffix only if the shared value does not already end with that exact suffix. The complete bucket name must fit within 63 characters; with `stage-`, a 12-digit account ID, and `us-east-1`, the base name without the suffix can be at most 34 characters. SNS base names are limited to 70 characters (to allow the SQS `-sub` suffix), and AppSync base names to 44, accounting for the longer `stage-` prefix.

The project creates S3, AppSync, and configured SNS/SQS resources. Each backend receives Pod Identity permissions only for its own S3 bucket and messaging resources. Cognito access uses separately supplied application credentials. Each frontend receives permissions only for its own AppSync APIs through Pod Identity. Both roles are bound to ServiceAccounts in their respective namespace. This frontend access is intended for server code, not browser JavaScript. Outputs remain keyed by `stage`/`prod`, with API/topic base names as nested keys.

Cover both application hostnames with exact or wildcard entries in `domain_name` and the existing ACM certificate. Configure DNS and the Istio Gateway/VirtualServices separately after Terraform installs Istio and its ingress gateway. `domain_name` controls which hostnames the ALB forwards.

Validate the root configuration and reusable module in PowerShell:

```powershell
terraform init -backend=false -input=false
if ($LASTEXITCODE -ne 0) { throw "Root initialization failed" }
terraform fmt -check -recursive
if ($LASTEXITCODE -ne 0) { throw "Formatting failed" }
terraform validate
if ($LASTEXITCODE -ne 0) { throw "Root validation failed" }
terraform test
if ($LASTEXITCODE -ne 0) { throw "Root integration tests failed" }
terraform '-chdir=modules/qualitypro' init -backend=false -input=false
if ($LASTEXITCODE -ne 0) { throw "Module initialization failed" }
terraform '-chdir=modules/qualitypro' validate
if ($LASTEXITCODE -ne 0) { throw "Module validation failed" }
terraform '-chdir=modules/qualitypro' test
if ($LASTEXITCODE -ne 0) { throw "Module tests failed" }
```

Initialization downloads pinned modules/providers and requires network access. Tests use offline plans or mocked apply/reapply/teardown without deploying resources. The root tests exercise a plan from empty state with the real VPC/EKS modules, plus the public module interface and output forwarding. Module tests cover private/versioned S3 buckets, namespace IAM isolation, direct S3-to-IAM wiring, shared EKS/Argo CD lifecycle, RDS placement in the shared VPC, EKS-only PostgreSQL ingress, TLS, managed administrator credentials, published metadata and RDS settings. They do not verify actual AWS authorization, regional engine/class availability, live Kubernetes readiness or pod-to-database connectivity.

## Private PostgreSQL and Administrator Access

The database has no public IP and uses the existing private subnets. Its security group accepts only the configured TCP port from the EKS node security group, without public CIDR ingress. Current VPC CNI assigns node security groups to pods, so backend pods can reach the private RDS hostname through the VPC. This network rule covers other pods on those nodes too; separate SQL users/permissions provide database access control. No public Ingress or ALB route exposes PostgreSQL. See [private RDS networking](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.WorkingWithRDSInstanceinaVPC.html) and [EKS VPC CNI security groups](https://docs.aws.amazon.com/eks/latest/best-practices/vpc-cni.html).

Database outputs include `database_host`, `database_port`, `database_endpoint`, `database_url`, `database_arn`, `database_security_group_id`, `master_username`, `master_user_secret_arn` and `database_metadata_parameter_name`. The URL is initially:

```text
postgresql://<private-rds-host>:5432/postgres?sslmode=require
```

The URL contains no username/password and targets the built-in administrative database. After creating application databases/users, configure backend applications with the host/port, their own database name and their own credentials. Terraform does not create SQL users, run SQL migrations or modify application Deployment configuration. For server certificate verification, configure the RDS CA bundle in the client and use `sslmode=verify-full`.

For Spring Boot, the datasource URL uses the `jdbc:postgresql://` scheme. Supply the host from `database_host`, and your database/user credentials through application environment variables:

```yaml
spring:
  datasource:
    url: "jdbc:postgresql://${DB_HOST}:${DB_PORT:5432}/${DB_NAME:postgres}?sslmode=require"
    username: ${DB_USER}
    password: ${DB_PASSWORD}
```

`postgres` is the initial administrative connection database; set `DB_NAME` to your application database after creating it. The application needs the PostgreSQL JDBC driver. With pgJDBC, `sslmode=require` encrypts the connection without requiring your own keys or validating the server certificate. Use `verify-full` with the RDS CA certificate when server identity verification is required. See [pgJDBC connection settings](https://jdbc.postgresql.org/documentation/use/) and [TLS modes](https://jdbc.postgresql.org/documentation/ssl/).

The initial administrator defaults to `postgres`. RDS generates and rotates its password in Secrets Manager; Terraform records only the secret reference and never fetches the secret value. IAM database authentication is disabled: PostgreSQL login uses username/password. IAM permissions are used only by the operator to retrieve the password from AWS. The existing External Secrets role's default `stage/*`/`prod/*` scope does not grant access to the RDS administrator secret. Store your future application users' credentials separately under those namespace prefixes. See [RDS-managed credentials](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html).

After Apply, obtain `master_user_secret_arn` from the workspace outputs, then retrieve the administrator secret using an authorized AWS CLI identity:

```powershell
$secretArn = '<master_user_secret_arn from HCP Terraform outputs>'
$credentials = aws secretsmanager get-secret-value --secret-id $secretArn --region us-east-1 --query SecretString --output text | ConvertFrom-Json
$credentials.username
$credentials.password
```

Use your deployment's region and AWS CLI profile. This reads the current username/password; do not save credentials in Git. The operator needs `secretsmanager:GetSecretValue` and, for a customer-managed secret encryption key, `kms:Decrypt`. You can also retrieve the secret in the AWS console. The non-secret `/qualitypro/<project_name>/database` SSM parameter continues to publish the endpoint and secret ARN for external tooling.

Run SQL from within the VPC, for example in an EKS pod with `psql` installed:

```powershell
psql "host=<database_host> port=5432 dbname=postgres user=postgres sslmode=require" -W
```

Enter the retrieved password when prompted. The `postgres` administrator can create your databases and application users. A machine outside the VPC cannot directly connect to this private endpoint. RDS administration is performed through its PostgreSQL privileges rather than unrestricted host/superuser access.

### Initial ALB Creation Troubleshooting

`Load Balancer is not ready yet` on `kubernetes_ingress_v1.app` means the Ingress did not receive an ALB address within the provider timeout. Inspect the controller logs for the underlying error:

```powershell
kubectl -n kube-system logs deployment/aws-load-balancer-controller --all-pods=true --tail=100
kubectl -n istio-system describe ingress app
```

If the controller reports `failed to refresh cached credentials, no EC2 IMDS role found`, check whether its Pods have `AWS_CONTAINER_CREDENTIALS_FULL_URI`, `AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE`, and the `eks-pod-identity-token` volume. EKS injects these when each Pod is created. [Pod Identity associations are eventually consistent](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html), so Pods started immediately after association creation can miss this injection and require recreation.

Terraform finishes VPC creation, including NAT gateways and routes, before creating EKS. It waits 30 seconds after creating or replacing each Pod Identity association for the ALB controller and External Secrets before installing the corresponding Helm release. Pod annotations track the association and role, causing a rolling update when they change and when this fix is first applied to an existing installation. This delay mitigates propagation latency; it is not an AWS readiness guarantee. If Kubernetes access is unavailable, CloudWatch Observability collects controller logs in `/aws/containerinsights/<cluster_name>/application`.

The Kubernetes provider is pinned to `3.2.1`, which [fixes `Unexpected Identity Change` after slow or failed resource creation](https://github.com/hashicorp/terraform-provider-kubernetes/blob/v3.2.1/CHANGELOG.md). Commit the root `.terraform.lock.hcl` together with `versions.tf` so HCP Terraform installs the matching version.

### Destruction and Redeployment in HCP Terraform

All resources belong to the same workspace/state. Terraform reverses the dependency graph during destruction, including deleting RDS before its subnets/VPC and retaining EKS/controller access until in-cluster cleanup finishes.

Before an intentional full destroy, apply `db_deletion_protection = false` and choose an unused `db_final_snapshot_identifier`, or deliberately enable `db_skip_final_snapshot`. Keep `s3_force_destroy = false` for normal deployments. If bucket contents and object versions should also be deleted, set it true and apply before destruction; this requires object/version deletion permissions and can still be prevented by Object Lock. Reset these opt-ins before another fresh deployment.

Use **Settings → Destruction and Deletion → Allow destroy plans → Queue destroy plan** in the one workspace. Keep the ALB controller, Pod Identity and network functional until Ingress deletion is finalized. Deleting a workspace/state does not delete AWS resources. Existing ACM certificates, Cognito pools, DNS records, application secrets and runner IAM/OIDC setup are managed separately. Container Insights log groups created outside Terraform state may remain. See [HCP destruction and deletion](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/settings/deletion).

Application namespaces depend on the External Secrets Helm release so that their `ExternalSecret` cleanup finalizers finish before the operator, its ServiceAccount and Pod Identity permissions are removed. If an older teardown left a namespace in `Terminating`, inspect `kubectl describe namespace <name>` for remaining resources and finalizers. Restore the responsible controller to complete cleanup; for an intentional full teardown, removing a known stale finalizer from the affected resource skips that controller's cleanup and requires checking any resources it managed.

## AWS Secrets Manager Integration

Terraform installs the pinned External Secrets Helm chart, CRDs, and the `external-secrets` ServiceAccount in the `external-secrets` namespace with Istio injection disabled. Its IAM role is bound through EKS Pod Identity and restricted to that cluster, namespace, and ServiceAccount. The operator watches resources across namespaces, including both `stage` and `prod`.

By default, the shared operator role can read secrets named <namespace>/* for every configured application namespace in `aws_region` and the current AWS account, for example `stage/database`. Set `external_secrets_secret_arns` to override this scope with explicit secret ARNs or ARN patterns. The role has read permissions only; it cannot create, update, or delete AWS secrets. Name/tag discovery with `dataFrom.find` is not enabled because `secretsmanager:ListSecrets` is not granted; use explicit remote keys or `dataFrom.extract`.

For secrets encrypted with customer-managed KMS keys, set `external_secrets_kms_key_arns`. Decrypt is restricted to Secrets Manager in `aws_region`; the key policy must also allow the operator role. Cross-account secrets additionally need a resource policy granting that role access.

Create the AWS secrets separately, then apply your own `SecretStore` and `ExternalSecret` YAML after `terraform apply`. These resources and secret values are not managed by Terraform. Use `apiVersion: external-secrets.io/v1`, put the `SecretStore` and `ExternalSecret` in the namespace where the resulting Kubernetes Secret is needed, and set `spec.provider.aws.service: SecretsManager` and `spec.provider.aws.region` to `aws_region`. Omit `auth` and `role` so the store uses the controller's Pod Identity credentials; do not configure `auth.jwt.serviceAccountRef` for this method. See [ESO AWS authentication](https://external-secrets.io/latest/provider/aws-access/#eks-pod-identity-setup).

The `external_secrets_namespace` and `external_secrets_pod_role_arn` outputs expose the installation namespace and IAM role. Argo CD's cluster-wide permissions allow deploying your namespaced `SecretStore` and `ExternalSecret` resources once the CRDs are installed.

## Self-hosted Argo CD

Terraform installs the pinned `argo-cd` Helm chart in `argocd`, with Istio injection disabled. `configs.params["server.insecure"] = true` disables TLS on the Argo CD UI/API server. The shared ALB terminates TLS using `acm_certificate_arn`, redirects external HTTP to HTTPS, and forwards all listed hostnames to the Istio ingress gateway over HTTP. Configure your own Istio Gateway/VirtualService to route the Argo CD hostname to `argocd-server.argocd.svc.cluster.local` on port `80`. Terraform does not create an Argo CD Ingress or its Istio routing resources. The public Argo CD URL remains HTTPS. Internal Kubernetes API TLS verification remains enabled. See [Argo CD TLS termination](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/).

The Helm chart creates ClusterRoles and ClusterRoleBindings for `argocd-application-controller` and `argocd-server` with `apiGroups`, `resources` and `verbs` set to `*`. Argo CD can deploy to any current or future namespace and manage cluster-scoped resources. Its Kubernetes permissions are independent of the `stage`/`prod` application namespaces and AWS resources Terraform provisions.

The local cluster Secret registers `in-cluster` in the `default` project using `https://kubernetes.default.svc`. Argo CD authenticates with its pod ServiceAccount. Applications should use:

```yaml
spec:
  project: default
  destination:
    name: in-cluster
    namespace: stage # Any target namespace, including one outside stage/prod.
```

Alternatively use `destination.server: https://kubernetes.default.svc` and omit `destination.name`. Configure Applications and repository credentials separately.

For a target namespace that does not exist yet, add `CreateNamespace=true` to the Application's `spec.syncPolicy.syncOptions`, or create the namespace beforehand. Application resources themselves remain in the `argocd` namespace.

After Apply in HCP Terraform, configure the CNAME using `alb_dns_name`, configure the Istio Gateway/VirtualService, then open `argocd_server_url`. Retrieve the generated initial administrator password in PowerShell:

```powershell
$initialPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($initialPassword))
```

Sign in as `admin` and change the password. For CLI access through this HTTP backend, use `argocd login <argocd-hostname> --grpc-web`. Dex is disabled; configure SSO separately if required.

## Steps After Deployment

Retrieve `alb_dns_name` and configure the CNAME for the selected domain. Verify that nodes, Istio components, and the ALB controller are ready, that the HTTPS listener is configured, and that targets are healthy. To sign in to Argo CD, use the URL from the `argocd_server_url` output and the local admin account. Configure its DNS record using `alb_dns_name`.

To make the application accessible through the domain, deploy its Deployment/Service separately and configure an Istio Gateway/VirtualService. The project delivers traffic to the ingress gateway but does not configure routing to the application. Local cluster registration and deployment permissions are configured automatically; create the Argo CD Application and configure repository access separately.

Run deployment and destruction from the repository root in the single workspace. For this fresh deployment, use a new empty HCP state. Existing ignored local state, variable files and caches are not inputs to a VCS-backed HCP run.
