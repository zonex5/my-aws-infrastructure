# Proposed Infrastructure Project for CPA QualityPro

This project deploys application infrastructure on Amazon EKS: networking, a Kubernetes cluster, HTTPS ingress, observability, and application access to AWS services. Each deployment manages one shared ALB, EKS cluster, Istio installation and Argo CD installation, plus all application namespaces configured in application_namespaces with separate backend/frontend permissions.

```text
Internet → application domain → public ALB → Istio ingress gateway
```

## Components Deployed

- A VPC with public/private subnets across two Availability Zones, an Internet Gateway, NAT gateways, routing, and an S3 Gateway VPC Endpoint.
- EKS with a Managed Node Group in private subnets, CoreDNS, kube-proxy, VPC CNI, and the EKS Pod Identity Agent.
- Istio: base components, istiod, and an ingress gateway with a NodePort Service.
- The AWS Load Balancer Controller and an Ingress that creates a public ALB with HTTPS and HTTP-to-HTTPS redirection.
- Each configured application namespace with Istio injection, backend/frontend ServiceAccounts, and separate IAM roles through EKS Pod Identity.
- One S3 bucket per application namespace and its configured AppSync Event APIs prefixed with that namespace; SNS topics, SQS queues, and subscriptions are created with the same prefix when topic names are configured.
- CloudWatch Observability for metrics and logs, plus EKS control plane logging.
- External Secrets Operator with CRDs in the dedicated `external-secrets` namespace, using EKS Pod Identity to read AWS Secrets Manager.
- Self-hosted Argo CD installed by Helm, behind the shared ALB and Istio ingress gateway, with local cluster registration, and Kubernetes RBAC for application deployment.

## Existing Resources to Prepare

### Domain and ACM Certificate

Set `domain_name` to a list of all hostnames that the shared ALB should forward to Istio, for example `["app.example.com", "argocd.example.com", "api.example.com"]`. Access to the DNS provider is required for certificate validation and subsequent CNAME configuration.

Prepare an issued ACM certificate covering every hostname in this list and supply its ARN in `acm_certificate_arn`. The certificate must be in the same region as the ALB. Before deployment, check that `aws_region` matches the region restriction in this variable's validation: the current configuration explicitly restricts the certificate region.

The project does not issue certificates or create DNS records. After deployment, use the `alb_dns_name` output as the CNAME target for the selected subdomain.

### Cognito User Pool

Prepare a separate existing User Pool in the infrastructure region for each namespace and supply its ID in `application_namespaces[namespace].cognito_user_pool_id`. This must be the pool ID, not its ARN or an App Client ID.

The project grants each namespace's backend IAM permissions to work with its own pool but does not create or modify the pool itself. User sign-in settings and application client integration remain outside the project's scope.

### Argo CD Domain

Set `argocd_domain_name` (for example `argocd.example.com`) for the public Argo CD URL and include it in `domain_name`. The ALB forwards exactly the hostnames listed in `domain_name`. The existing `acm_certificate_arn` must cover all listed hostnames. Point its hostname to the shared `alb_dns_name` output and configure your Istio Gateway/VirtualService for this hostname. The Helm installation enables the local `admin` account.

## Parameters to Configure Before Deployment

Populate `terraform.tfvars` with the prepared values and environment settings:

- **Environment:** `aws_region`, `cluster_name`, `domain_name`, `argocd_domain_name`, `application_namespaces` (a map keyed by namespace).
- **Networking and nodes:** `vpc_cidr`, `public_subnet_cidrs`, `private_subnet_cidrs`, `nat_gateway_per_az`, `cluster_endpoint_public_access_cidrs`, `node_instance_types`, `node_min_size`, `node_max_size`, `node_desired_size`. Allocate sufficient capacity for system components and applications; EKS API access must allow the network from which deployment runs.
- **Existing resources:** the shared `acm_certificate_arn` and a separate `cognito_user_pool_id` inside each `application_namespaces` entry.
- **Application resources to create:** inside each `application_namespaces` entry, the required `s3_bucket_name` is a base name for a new bucket, not the name of an existing bucket; the required `appsync_event_api_name` is a non-empty list of API base names. `backend_sns_topic_names` defines the topic list; an empty or omitted list disables SNS/SQS creation for that namespace. The optional `appsync_event_namespace_name` defaults to `events`.

There is no need to create S3 buckets, AppSync APIs, or SNS/SQS resources beforehand: the project creates them for each configured application namespace. The backend receives access to S3, Cognito, and configured SNS/SQS resources; the frontend receives AppSync access through its pod IAM role. Both roles are bound to their ServiceAccounts in that namespace. This access is intended for frontend server code, not JavaScript running in a browser.

For example:

```hcl
application_namespaces = {
  stage = {
    cognito_user_pool_id    = "us-east-1_Stage123"
    s3_bucket_name          = "docs"
    backend_sns_topic_names = ["notifications", "audit"]
    appsync_event_api_name  = ["events", "other"]
  }
}
```

This creates `stage-docs-<account-id>-<region>`, SNS topics `stage-notifications` and `stage-audit`, SQS queues `stage-notifications-sub` and `stage-audit-sub`, and AppSync APIs `stage-events` and `stage-other`. IAM role names keep the `<cluster_name>-stage-` prefix.

Use the same Terraform state for all namespaces in this shared cluster. To add prod later, keep stage in application_namespaces and add a prod entry with its own existing Cognito pool and application resource settings. Keep cluster_name and shared infrastructure settings unchanged. Add its hostnames to domain_name and ensure the existing ACM certificate covers them; DNS and Istio routing remain configured separately.

Create the Istio Gateway and VirtualServices separately after Terraform installs Istio and its ingress gateway. `domain_name` controls which hostnames the ALB forwards.

Validate changes with `terraform fmt -check -recursive`, `terraform validate`, and `terraform test`. The tests check offline plans and a mocked apply/teardown cycle, without contacting AWS or Kubernetes. The lifecycle test verifies Terraform's dependency handling; it does not validate live AWS authorization or real cluster deletion.

## AWS Secrets Manager Integration

Terraform installs the pinned External Secrets Helm chart, CRDs, and the `external-secrets` ServiceAccount in the `external-secrets` namespace with Istio injection disabled. Its IAM role is bound through EKS Pod Identity and restricted to that cluster, namespace, and ServiceAccount. The operator watches resources across namespaces, including all configured application namespaces.

By default, the shared operator role can read secrets named <namespace>/* for every configured application namespace in `aws_region` and the current AWS account, for example `stage/database`. Set `external_secrets_secret_arns` to override this scope with explicit secret ARNs or ARN patterns. The role has read permissions only; it cannot create, update, or delete AWS secrets. Name/tag discovery with `dataFrom.find` is not enabled because `secretsmanager:ListSecrets` is not granted; use explicit remote keys or `dataFrom.extract`.

For secrets encrypted with customer-managed KMS keys, set `external_secrets_kms_key_arns`. Decrypt is restricted to Secrets Manager in `aws_region`; the key policy must also allow the operator role. Cross-account secrets additionally need a resource policy granting that role access.

Create the AWS secrets separately, then apply your own `SecretStore` and `ExternalSecret` YAML after `terraform apply`. These resources and secret values are not managed by Terraform. Use `apiVersion: external-secrets.io/v1`, put the `SecretStore` and `ExternalSecret` in the namespace where the resulting Kubernetes Secret is needed, and set `spec.provider.aws.service: SecretsManager` and `spec.provider.aws.region` to `aws_region`. Omit `auth` and `role` so the store uses the controller's Pod Identity credentials; do not configure `auth.jwt.serviceAccountRef` for this method. See [ESO AWS authentication](https://external-secrets.io/latest/provider/aws-access/#eks-pod-identity-setup).

The `external_secrets_namespace` and `external_secrets_pod_role_arn` outputs expose the installation namespace and IAM role. Argo CD's cluster-wide permissions allow deploying your namespaced `SecretStore` and `ExternalSecret` resources once the CRDs are installed.

## Self-hosted Argo CD

Terraform installs the pinned `argo-cd` Helm chart in `argocd`, with Istio injection disabled. `configs.params["server.insecure"] = true` disables TLS on the Argo CD UI/API server. The shared ALB terminates TLS using `acm_certificate_arn`, redirects external HTTP to HTTPS, and forwards all listed hostnames to the Istio ingress gateway over HTTP. Configure your own Istio Gateway/VirtualService to route the Argo CD hostname to `argocd-server.argocd.svc.cluster.local` on port `80`. Terraform does not create an Argo CD Ingress or its Istio routing resources. The public Argo CD URL remains HTTPS. Internal Kubernetes API TLS verification remains enabled. See [Argo CD TLS termination](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/).

The Helm chart creates ClusterRoles and ClusterRoleBindings for `argocd-application-controller` and `argocd-server` with `apiGroups`, `resources` and `verbs` set to `*`. Argo CD can deploy to any current or future namespace and manage cluster-scoped resources. Its Kubernetes permissions are independent of `application_namespaces`, which controls only the application namespaces and AWS resources Terraform provisions.

The local cluster Secret registers `in-cluster` in the `default` project using `https://kubernetes.default.svc`. Argo CD authenticates with its pod ServiceAccount. Applications should use:

```yaml
spec:
  project: default
  destination:
    name: in-cluster
    namespace: stage # Any target namespace, including one outside application_namespaces.
```

Alternatively use `destination.server: https://kubernetes.default.svc` and omit `destination.name`. Configure Applications and repository credentials separately.

For a target namespace that does not exist yet, add `CreateNamespace=true` to the Application's `spec.syncPolicy.syncOptions`, or create the namespace beforehand. Application resources themselves remain in the `argocd` namespace.

Run `terraform init`, `terraform plan`, review the plan, then `terraform apply`. Configure the CNAME using `alb_dns_name`, configure the Istio Gateway/VirtualService, then open `argocd_server_url`. Retrieve the generated initial administrator password in PowerShell:

```powershell
$initialPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($initialPassword))
```

Sign in as `admin` and change the password. For CLI access through this HTTP backend, use `argocd login <argocd-hostname> --grpc-web`. Dex is disabled; configure SSO separately if required.

## Steps After Deployment

Retrieve `alb_dns_name` and configure the CNAME for the selected domain. Verify that nodes, Istio components, and the ALB controller are ready, that the HTTPS listener is configured, and that targets are healthy. To sign in to Argo CD, use the URL from the `argocd_server_url` output and the local admin account. Configure its DNS record using `alb_dns_name`.

To make the application accessible through the domain, deploy its Deployment/Service separately and configure an Istio Gateway/VirtualService. The project delivers traffic to the ingress gateway but does not configure routing to the application. Local cluster registration and deployment permissions are configured automatically; create the Argo CD Application and configure repository access separately.

Terraform state is stored locally; keep a backup to continue managing the deployed infrastructure.
