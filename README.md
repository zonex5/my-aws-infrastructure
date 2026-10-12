# Proposed Infrastructure Project for CPA QualityPro

This project deploys application infrastructure on Amazon EKS: networking, a Kubernetes cluster, HTTPS ingress, observability, and application access to AWS services. Each deployment manages one shared ALB, EKS cluster, Istio installation and Argo CD installation, plus both `stage` and `prod` application namespaces with separate backend/frontend permissions. Two independent HCP Terraform workspaces separate the cluster lifecycle from S3 storage. Both environments are managed together within each workspace.

```text
Internet → application domain → public ALB → Istio ingress gateway
```

## Components Deployed

- A VPC with public/private subnets across two Availability Zones, an Internet Gateway, NAT gateways, routing, and an S3 Gateway VPC Endpoint.
- EKS with a Managed Node Group in private subnets, CoreDNS, kube-proxy, VPC CNI, and the EKS Pod Identity Agent.
- Istio: base components, istiod, and an ingress gateway with a NodePort Service.
- The AWS Load Balancer Controller and an Ingress that creates a public ALB with HTTPS and HTTP-to-HTTPS redirection.
- Both `stage` and `prod` application namespaces with Istio injection, backend/frontend ServiceAccounts, and separate IAM roles through EKS Pod Identity.
- One S3 bucket per application namespace, plus AppSync Event APIs, SNS topics, SQS queues, and subscriptions from shared base names, prefixed with `stage-` or `prod-`. An empty SNS topic list disables messaging in both environments.
- CloudWatch Observability for metrics and logs, plus EKS control plane logging.
- External Secrets Operator with CRDs in the dedicated `external-secrets` namespace, using EKS Pod Identity to read AWS Secrets Manager.
- Self-hosted Argo CD installed by Helm, behind the shared ALB and Istio ingress gateway, with local cluster registration, and Kubernetes RBAC for application deployment.

## Project Structure and HCP Terraform Setup

This structure is intended for a fresh installation. Create two VCS-backed workspaces connected to this repository, each with its own state and variables:

| Workspace name | Terraform Working Directory | Resources |
| --- | --- | --- |
| `1-storage` | `1-storage` | Stage/prod S3 buckets, public access blocks, AES256 encryption, versioning, SSM storage metadata |
| `2-infrastructure` | `2-infrastructure` | VPC, NAT, S3 VPC Endpoint, EKS, Kubernetes/Helm components, IAM/Pod Identity, AppSync, SNS/SQS |

Each directory is a standalone root module with its own `versions.tf`, providers, variables, outputs, tests, example variables and `.terraform.lock.hcl`. The repository root contains documentation rather than an executable Terraform module. Storage requires only the AWS provider; it does not depend on EKS, Cognito, Kubernetes or Helm. The S3 VPC Endpoint belongs to infrastructure because it depends on the VPC and route tables. AppSync and SNS/SQS also belong to infrastructure and are deleted with that workspace's resources.

1. Set each workspace's **Settings → General → Terraform Working Directory** to the directory in the table and choose the same supported Terraform CLI version (1.9 or newer, below 2.0). HCP Terraform manages state automatically for VCS-backed remote runs; no organization name or credentials are committed in a backend block. Keep both lock files in Git. See [workspace settings](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/settings).
2. Configure AWS authentication separately in both workspaces, using the same account and region. The infrastructure runner needs AWS CLI available for `aws eks get-token` and network access to the EKS API. Configure the existing AWS/OIDC trust for both workspace identities if using dynamic credentials. Storage needs permissions for S3 management and creating, reading, updating, tagging and deleting its SSM parameter; infrastructure needs permissions for its network, EKS, IAM and application services plus `ssm:GetParameter` on `/qualitypro/<project_name>/storage`. These are permissions on the existing AWS runner identities; application Pod Identity roles do not read this parameter.
3. Add the storage Terraform variables from the table below. Apply `1-storage` first. Terraform creates the buckets and their security settings, then automatically publishes non-secret bucket metadata as a Standard String parameter at **`/qualitypro/<project_name>/storage`** in AWS SSM Parameter Store.
4. Add the infrastructure Terraform variables using the same **`project_name`** and **`aws_region`** as storage. The project identifier is stable and can differ from `cluster_name`; infrastructure discovers storage through the project path without knowing any HCP workspace names. The existing AWS provider reads the parameter and verifies its metadata version, AWS account, region and stage/prod ARN keys. No additional API tokens, HCP state access or manual workspace-sharing settings are needed.
5. Plan and apply `2-infrastructure` after storage's successful apply. The first-deployment order is **`1-storage` → `2-infrastructure`**. Publication and discovery are managed entirely in Terraform. See [SSM parameter resource](https://registry.terraform.io/providers/hashicorp/aws/6.52.0/docs/resources/ssm_parameter) and [SSM parameter data source](https://registry.terraform.io/providers/hashicorp/aws/6.52.0/docs/data-sources/ssm_parameter).

The SSM metadata contains `schema_version = 1`, `s3_bucket_name` and `s3_bucket_arn` maps keyed by `stage`/`prod`, plus `aws_account_id` and `aws_region`. The same bucket/account/region values remain available as outputs in the storage workspace, together with `storage_metadata_parameter_name`. Infrastructure consumes the published bucket ARNs for backend IAM policies without reading another Terraform state, reconstructing bucket names or managing the buckets. Cluster, application identity, messaging, AppSync and ingress outputs are available in infrastructure. Recreating infrastructure with the same account, region and project identifier reuses the existing buckets.

## Existing Resources to Prepare

### Domain and ACM Certificate

Set `domain_name` to a list of all hostnames that the shared ALB should forward to Istio, for example `["app.example.com", "argocd.example.com", "api.example.com"]`. Access to the DNS provider is required for certificate validation and subsequent CNAME configuration.

Prepare an issued ACM certificate covering every hostname in this list and supply its ARN in `acm_certificate_arn`. The certificate must be in the same region as the ALB. Before deployment, check that `aws_region` matches the region restriction in this variable's validation: the current configuration explicitly restricts the certificate region.

The project does not issue certificates or create DNS records. After deployment, use the `alb_dns_name` output as the CNAME target for the selected subdomain.

### Cognito User Pool

Set `stage_cognito_user_pool_id` and `prod_cognito_user_pool_id` independently to existing User Pool IDs in the infrastructure region. Both environments may temporarily use the same pool; replace the prod ID when its own pool is ready. This must be the pool ID, not its ARN or an App Client ID.

The project grants each namespace's backend IAM permissions to work with its own pool but does not create or modify the pool itself. User sign-in settings and application client integration remain outside the project's scope.

### Argo CD Domain

Set `argocd_domain_name` (for example `argocd.example.com`) for the public Argo CD URL and include it in `domain_name`. The ALB forwards exactly the hostnames listed in `domain_name`. The existing `acm_certificate_arn` must cover all listed hostnames. Point its hostname to the shared `alb_dns_name` output and configure your Istio Gateway/VirtualService for this hostname. The Helm installation enables the local `admin` account.

## Parameters to Configure Before Deployment

Use Terraform 1.9 or newer. Both `stage` and `prod` are always created in the same shared EKS cluster, while their S3 buckets are managed together in the separate storage workspace.

Each root module has a `terraform.tfvars.example`; use the matching file as a reference for its workspace variables. If using local configuration files, copy the example to `terraform.tfvars` inside the corresponding directory and keep real values out of Git. Deployment uses the HCP VCS-backed workflow above. Local validation and mocked tests are documented below. For HCP Terraform, add the following keys in **Variables → Terraform variables**. Shared application settings are flat root variables; there is no nested `application_namespaces` input to duplicate per environment.

Strings in the table are entered without surrounding quotes with HCL disabled. Enable HCL for lists, booleans, numbers, and `null`, entering only the value, not `key = value`. See [HCP Terraform variable values](https://developer.hashicorp.com/terraform/cloud-docs/variables/managing-variables).

Every variable without a `default` is required and uses `nullable = false`: supply each required value before planning. Variables with defaults remain optional. `node_instance_type` accepts one string, for example `c7i-flex.large` with HCL disabled; Terraform wraps it in a single-element list for the EKS module.

### Storage variables (`1-storage`)

| Variable key | Example value in HCP Terraform | HCL | Required / default |
| --- | --- | --- | --- |
| `aws_region` | `us-east-1` | No | Required; same as infrastructure |
| `project_name` | `my-cluster` | No | Required; stable identifier shared with infrastructure, 1-64 letters/digits/underscores/hyphens |
| `s3_bucket_name` | `qualitypro-docs` | No | Required; shared base name |
| `s3_force_destroy` | `false` | Yes | Optional; `false`; allow deleting bucket contents during storage destroy |

### Infrastructure variables (`2-infrastructure`)

| Variable key | Example value in HCP Terraform | HCL | Required / default |
| --- | --- | --- | --- |
| `project_name` | `my-cluster` | No | Required; same stable project identifier as storage |
| `domain_name` | `["stage.example.com", "prod.example.com", "argocd.example.com"]` | Yes | Required |
| `argocd_domain_name` | `argocd.example.com` | No | Required |
| `acm_certificate_arn` | `arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000` | No | Required |
| `stage_cognito_user_pool_id` | `us-east-1_Stage123` | No | Required |
| `prod_cognito_user_pool_id` | `us-east-1_Prod123` | No | Required; configured separately |
| `appsync_event_api_name` | `["events", "other"]` | Yes | Required; non-empty shared list |
| `backend_sns_topic_names` | `["notifications", "audit"]` | Yes | Optional; `[]` |
| `appsync_event_namespace_name` | `events` | No | Optional; `events` |
| `aws_region` | `us-east-1` | No | Required |
| `cluster_name` | `my-cluster` | No | Required |
| `kubernetes_version` | `1.36` | No | Required |
| `vpc_cidr` | `10.0.0.0/16` | No | Optional; `10.0.0.0/16` |
| `public_subnet_cidrs` | `["10.0.0.0/24", "10.0.1.0/24"]` | Yes | Optional; shown value |
| `private_subnet_cidrs` | `["10.0.10.0/24", "10.0.11.0/24"]` | Yes | Optional; shown value |
| `nat_gateway_per_az` | `true` | Yes | Optional; `true` |
| `cluster_endpoint_public_access_cidrs` | `["103.0.13.10/32"]` | Yes | Optional; `["0.0.0.0/0"]`; set trusted CIDRs |
| `node_instance_type` | `c7i-flex.large` | No | Optional; `c7i-flex.large` |
| `node_capacity_type` | `ON_DEMAND` | No | Optional; `ON_DEMAND` |
| `node_min_size` | `2` | Yes | Required |
| `node_max_size` | `2` | Yes | Required |
| `node_desired_size` | `2` | Yes | Required |
| `cloudwatch_log_retention_days` | `30` | Yes | Optional; `30` |
| `cloudwatch_addon_version` | `null` | Yes | Optional; `null` selects latest compatible build |
| `external_secrets_secret_arns` | `["arn:aws:secretsmanager:us-east-1:123456789012:secret:stage/*", "arn:aws:secretsmanager:us-east-1:123456789012:secret:prod/*"]` | Yes | Optional; `[]` grants both namespace prefixes |
| `external_secrets_kms_key_arns` | `["arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"]` | Yes | Optional; `[]` |

Allocate sufficient node capacity for system components and applications in both environments. EKS API access must allow the network from which Terraform runs. Configure AWS authentication for the runner separately.

The shared application values are entered once in infrastructure:

```hcl
stage_cognito_user_pool_id = "us-east-1_Stage123"
prod_cognito_user_pool_id  = "us-east-1_Prod123"
backend_sns_topic_names   = ["notifications", "audit"]
appsync_event_api_name    = ["events", "other"]
```

Set `s3_bucket_name = "qualitypro-docs"` once in storage. Together the two workspaces create both sets of resources:

| Resource | stage | prod |
| --- | --- | --- |
| Kubernetes namespace | `stage` | `prod` |
| S3 bucket | `stage-qualitypro-docs-123456789012-us-east-1` | `prod-qualitypro-docs-123456789012-us-east-1` |
| SNS topics | `stage-notifications`, `stage-audit` | `prod-notifications`, `prod-audit` |
| SQS queues | `stage-notifications-sub`, `stage-audit-sub` | `prod-notifications-sub`, `prod-audit-sub` |
| AppSync APIs | `stage-events`, `stage-other` | `prod-events`, `prod-other` |
| Existing Cognito pool | `us-east-1_Stage123` | `us-east-1_Prod123` |

S3 bucket names use `<namespace>-<s3_bucket_name>-<account-id>-<region>`. Terraform appends the current account/region suffix only if the shared value does not already end with that exact suffix. The complete bucket name must fit within 63 characters; with `stage-`, a 12-digit account ID, and `us-east-1`, the base name without the suffix can be at most 34 characters. SNS base names are limited to 70 characters (to allow the SQS `-sub` suffix), and AppSync base names to 44, accounting for the longer `stage-` prefix.

The project creates S3, AppSync, and configured SNS/SQS resources. Each backend receives permissions only for its own S3 bucket, configured existing Cognito pool, and messaging resources. Each frontend receives permissions only for its own AppSync APIs through Pod Identity. Both roles are bound to ServiceAccounts in their respective namespace. This frontend access is intended for server code, not browser JavaScript. Outputs remain keyed by `stage`/`prod`, with API/topic base names as nested keys.

Include both application hostnames in `domain_name` and the existing ACM certificate. Configure DNS and the Istio Gateway/VirtualServices separately after Terraform installs Istio and its ingress gateway. `domain_name` controls which hostnames the ALB forwards.

Validate both root modules from the repository root in PowerShell:

```powershell
foreach ($rootModule in @("1-storage", "2-infrastructure")) {
  terraform "-chdir=$rootModule" init -backend=false -input=false
  if ($LASTEXITCODE -ne 0) { throw "Initialization failed: $rootModule" }
  terraform "-chdir=$rootModule" fmt -check -recursive
  if ($LASTEXITCODE -ne 0) { throw "Formatting failed: $rootModule" }
  terraform "-chdir=$rootModule" validate
  if ($LASTEXITCODE -ne 0) { throw "Validation failed: $rootModule" }
  terraform "-chdir=$rootModule" test
  if ($LASTEXITCODE -ne 0) { throw "Tests failed: $rootModule" }
}
```

Initialization downloads modules/providers and requires network access. The tests check offline plans and mocked apply/teardown cycles without contacting AWS, Kubernetes or HCP Terraform. Infrastructure tests substitute the SSM metadata and verify namespace-specific IAM grants, project-based discovery, and rejection of account/region/version mismatches. Storage tests verify bucket naming, privacy, encryption, versioning, automatic SSM publication, outputs and the storage-only teardown option. Lifecycle tests verify Terraform's dependency handling; they do not validate live authorization or real resource deletion.

### Initial ALB Creation Troubleshooting

`Load Balancer is not ready yet` on `kubernetes_ingress_v1.app` means the Ingress did not receive an ALB address within the provider timeout. Inspect the controller logs for the underlying error:

```powershell
kubectl -n kube-system logs deployment/aws-load-balancer-controller --all-pods=true --tail=100
kubectl -n istio-system describe ingress app
```

If the controller reports `failed to refresh cached credentials, no EC2 IMDS role found`, check whether its Pods have `AWS_CONTAINER_CREDENTIALS_FULL_URI`, `AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE`, and the `eks-pod-identity-token` volume. EKS injects these when each Pod is created. [Pod Identity associations are eventually consistent](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html), so Pods started immediately after association creation can miss this injection and require recreation.

Terraform finishes VPC creation, including NAT gateways and routes, before creating EKS. It waits 30 seconds after creating or replacing each Pod Identity association for the ALB controller and External Secrets before installing the corresponding Helm release. Pod annotations track the association and role, causing a rolling update when they change and when this fix is first applied to an existing installation. This delay mitigates propagation latency; it is not an AWS readiness guarantee. If Kubernetes access is unavailable, CloudWatch Observability collects controller logs in `/aws/containerinsights/<cluster_name>/application`.

The Kubernetes provider is pinned to `3.2.1`, which [fixes `Unexpected Identity Change` after slow or failed resource creation](https://github.com/hashicorp/terraform-provider-kubernetes/blob/v3.2.1/CHANGELOG.md). Commit `2-infrastructure/.terraform.lock.hcl` together with its `versions.tf` so HCP Terraform installs the matching version.

### Independent Destruction and Redeployment in HCP Terraform

To recreate only the cluster and its application infrastructure, queue a destroy plan in **2-infrastructure**, review it and apply it. Its state contains no S3 buckets, their configuration resources or the published SSM parameter, so storage remains managed by **1-storage**. Keep storage and its metadata parameter available while planning/applying infrastructure. Then queue a normal infrastructure Plan → Apply using the same project identifier; update DNS with the new `alb_dns_name` and restore externally configured Istio routing and Argo CD Applications. AppSync and SNS/SQS are recreated along with infrastructure.

For a complete teardown, destroy **2-infrastructure first**, then explicitly destroy **1-storage**. Only the storage workspace controls `s3_force_destroy`. Keep it `false` for normal use. If all bucket contents and object versions should be deleted, set it to `true` with HCL enabled in **1-storage** and apply that change before queuing its destroy. The AWS runner needs object/version deletion permissions, and Object Lock restrictions can still prevent deletion. Reset the value to `false` before a later fresh storage deployment.

Use **Settings → Destruction and Deletion → Allow destroy plans → Queue destroy plan** in the intended workspace. Keep the ALB controller, Pod Identity and network functional until Ingress deletion is finalized. Deleting a workspace/state does not delete AWS resources. Existing ACM certificates, Cognito pools, DNS records, AWS secrets and runner IAM/OIDC setup are managed separately. AWS schedules KMS key deletion; Container Insights log groups created outside Terraform state may remain. See [HCP Terraform destruction and deletion](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/settings/deletion).

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

After applying storage and then infrastructure through HCP Terraform, configure the CNAME using infrastructure's `alb_dns_name`, configure the Istio Gateway/VirtualService, then open `argocd_server_url`. Retrieve the generated initial administrator password in PowerShell:

```powershell
$initialPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($initialPassword))
```

Sign in as `admin` and change the password. For CLI access through this HTTP backend, use `argocd login <argocd-hostname> --grpc-web`. Dex is disabled; configure SSO separately if required.

## Steps After Deployment

Retrieve `alb_dns_name` and configure the CNAME for the selected domain. Verify that nodes, Istio components, and the ALB controller are ready, that the HTTPS listener is configured, and that targets are healthy. To sign in to Argo CD, use the URL from the `argocd_server_url` output and the local admin account. Configure its DNS record using `alb_dns_name`.

To make the application accessible through the domain, deploy its Deployment/Service separately and configure an Istio Gateway/VirtualService. The project delivers traffic to the ingress gateway but does not configure routing to the application. Local cluster registration and deployment permissions are configured automatically; create the Argo CD Application and configure repository access separately.

The two HCP Terraform workspaces each retain their own state. Run deployment and destruction in the intended workspace; the repository root is not a deployment directory. Local root-level state, variable files and previous `.terraform` caches are not inputs to these new HCP workspaces.
