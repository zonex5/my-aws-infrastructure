# QualityPro infrastructure module

Creates one VPC, EKS cluster, ALB ingress, Istio, Argo CD, External Secrets Operator, observability and private RDS PostgreSQL instance. Both `stage` and `prod` share the cluster and database instance; they receive separate namespaces, S3 buckets, backend/frontend IAM roles, AppSync APIs and configured SNS/SQS resources.

The repository root is a complete caller example: `main.tf` passes the inputs, `providers.tf` configures AWS/Kubernetes/Helm, and `terraform.tfvars.example` lists deployment values. The module accepts no AWS credentials and configures no backend or provider internally. Its resources are owned by the caller's single state.

Configure the AWS provider for `aws_region` and the intended account. Configure Kubernetes and Helm with this module's `cluster_endpoint` and base64-decoded `cluster_certificate_authority_data`, using AWS CLI `eks get-token` with `cluster_name` and `aws_region`. Pass those providers and time through the module call. Do not add broad `depends_on` to the module call: Kubernetes/Helm provider configuration depends on the EKS outputs, while AWS resources must be able to create that cluster first.

All required and optional inputs are defined in `variables.tf`; `outputs.tf` exposes cluster/network identifiers, namespace-specific application resources, Argo CD details and credential-free database connection metadata. No SQL databases/users beyond RDS's built-in administration setup are provisioned. RDS generates and manages the administrator password in Secrets Manager; Terraform exposes only the secret ARN.

S3-to-IAM and network-to-RDS dependencies use direct resource references. SSM parameters at `/qualitypro/<project_name>/{storage,network,database}` publish non-secret metadata for external tooling and are not read to connect parts of this module.

See the root README for fresh deployment, runner permissions, live Kubernetes access, testing and destruction instructions. Run `terraform test` in this directory for the module's offline/mocked tests; run the root tests separately to verify the caller interface.
