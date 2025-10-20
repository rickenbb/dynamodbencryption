# DynamoDB Client-Side Encryption Demo Notes

## Overview
- Terraform provisions the supporting AWS resources: a DynamoDB table (`pk`/`sk` keys), two customer-managed KMS keys (one for client-side encryption, one for DynamoDB SSE), and two IAM users for access testing.
- `terraform/main.tf` also emits a `.env` file at the repo root containing runtime configuration for `demo.py`.
- `demo.py` wraps the DynamoDB table with the DynamoDB Encryption Client, encrypts the `secret` attribute while signing the rest, stores a sample item, and then retrieves both the decrypted and raw representations.

## Generated Configuration
- `.env` includes `AWS_REGION`, `DEMO_TABLE_NAME`, `DEMO_CLIENT_KMS_KEY_ARN`, `FULL_USER_NAME`, and `LIMITED_USER_NAME`. Only `DEMO_CLIENT_KMS_KEY_ARN` is consumed by the Python script; the user names assist with credential testing.
- The DynamoDB table also uses the storage CMK for server-side encryption, configured through Terraform.

## Runtime Behavior (`demo.py`)
- Builds an `EncryptedTable` with `AwsKmsCryptographicMaterialsProvider(key_id=DEMO_CLIENT_KMS_KEY_ARN)`.
- Applies `CryptoAction.ENCRYPT_AND_SIGN` to the `secret` attribute and `SIGN_ONLY` to everything else, preserving DynamoDB indexing on `pk`/`sk`.
- Persists a sample item and retrieves it twice:
  - Through the encryption client (`EncryptedTable.get_item`) to show decrypted values.
  - Through the raw DynamoDB client (`boto3.client("dynamodb").get_item`) to expose the ciphertext stored at rest.

## IAM Model
- **Full user** (`FULL_USER_NAME`): attached to the broad DynamoDB policy plus both KMS policies (`kms_client_full` and `kms_storage_via_service`), enabling client-side and DynamoDB-managed encryption flows to succeed.
- **Limited user** (`LIMITED_USER_NAME`): shares the same DynamoDB access but has no KMS permissions. CRUD and management operations work, yet any Encrypt/Decrypt/GenerateDataKey calls from the Python demo fail with `AccessDeniedException`, leaving only ciphertext visible.

## Design Considerations
- Keeping primary key attributes unsigned-only avoids breaking partitioning, query filters, or index lookups. If sensitive identifiers must be hidden, introduce surrogate keys (hash/token) that remain plaintext for DynamoDB while storing real values in encrypted attributes.
- Client-side and server-side encryptions are intentionally separated so you can evaluate their behaviors independently.

## Experiment Ideas
- Switch AWS credentials between the full and limited users to observe how KMS permissions affect the demo.
- Extend `attribute_actions` to encrypt additional fields, or add deterministic encryption strategies if you need queryable ciphertext.
- Inspect the DynamoDB item in the AWS Console to compare the stored ciphertext with the decrypted output printed by `demo.py`.
- Adapt the Terraform module to model cross-account key sharing (e.g., by adjusting the key policy with specific principals or encryption context requirements).
