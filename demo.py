#!/usr/bin/env python3
"""
Minimal DynamoDB client-side encryption example.

Prerequisites:
  * Terraform provisioning to create the table and KMS keys (see ./terraform).
  * `pip install -r requirements.txt`
  * AWS credentials with access to the provisioned resources and permission to use the client-side CMK.
"""
import os
import sys
from typing import Any, Dict

import boto3
from botocore.exceptions import ClientError
from dynamodb_encryption_sdk.encrypted.table import EncryptedTable
from dynamodb_encryption_sdk.identifiers import CryptoAction
from dynamodb_encryption_sdk.material_providers.aws_kms import (
    AwsKmsCryptographicMaterialsProvider,
)
from dynamodb_encryption_sdk.structures import AttributeActions


def build_encrypted_table(table_name: str, key_arn: str, region: str) -> EncryptedTable:
    """
    Wrap a DynamoDB table with the encryption client.

    The attribute actions encrypt the `secret` field while signing everything.
    """
    session = boto3.Session(region_name=region)
    dynamodb_table = session.resource("dynamodb").Table(table_name)

    # DynamoDB server-side encryption uses a different CMK defined in Terraform; this
    # keyring focuses on client-side envelope encryption for sensitive attributes.
    cmp = AwsKmsCryptographicMaterialsProvider(key_id=key_arn)

    actions = AttributeActions(
        default_action=CryptoAction.SIGN_ONLY,
        attribute_actions={"secret": CryptoAction.ENCRYPT_AND_SIGN},
    )
    # `pk` and `sk` remain SIGN_ONLY so DynamoDB can still index and resolve items.
    # Encrypting key attributes would produce opaque ciphertext values, breaking lookups.

    return EncryptedTable(
        table=dynamodb_table,
        materials_provider=cmp,
        attribute_actions=actions,
    )


def put_demo_item(
    table: EncryptedTable,
    partition_key: str,
    sort_key: str,
    secret_value: str,
    visible_value: str,
) -> None:
    item: Dict[str, Any] = {
        "pk": partition_key,
        "sk": sort_key,
        "secret": secret_value,
        "message": visible_value,
    }
    table.put_item(Item=item)


def show_raw_item(table_name: str, key: Dict[str, Any], region: str) -> Dict[str, Any]:
    client = boto3.client("dynamodb", region_name=region)
    response = client.get_item(TableName=table_name, Key=key, ConsistentRead=True)
    return response.get("Item", {})


def main() -> int:
    table_name = os.environ.get("DEMO_TABLE_NAME")
    key_arn = os.environ.get("DEMO_CLIENT_KMS_KEY_ARN")
    region = os.environ.get("AWS_REGION")

    if not table_name or not key_arn or not region:
        print(
            "Set DEMO_TABLE_NAME, DEMO_CLIENT_KMS_KEY_ARN, and AWS_REGION in the environment.",
            file=sys.stderr,
        )
        return 1

    try:
        encrypted_table = build_encrypted_table(table_name, key_arn, region)
    except ClientError as exc:
        print(f"Failed to access DynamoDB table or KMS key: {exc}", file=sys.stderr)
        return 1

    partition_key = "example-user-001"
    sort_key = "profile"

    put_demo_item(
        table=encrypted_table,
        partition_key=partition_key,
        sort_key=sort_key,
        secret_value="very-secret-value",
        visible_value="hello from the plaintext attribute",
    )

    decrypted = encrypted_table.get_item(Key={"pk": partition_key, "sk": sort_key})
    raw = show_raw_item(
        table_name,
        key={"pk": {"S": partition_key}, "sk": {"S": sort_key}},
        region=region,
    )

    print("Decrypted response:")
    print(decrypted["Item"])
    print("\nRaw DynamoDB item (shows ciphertext):")
    print(raw)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
