# CCCD Migrator

A CLI that wraps calls to the `aws cli` for s3 synchronization and `pg_dump/psql` for RDS/postgres database "migration". Both data stores are unidirectionally copied from template deploy environments (source) to live-1 (destination).

## Build
To build the docker image using the provided script you will need credentials for accessing live-1 cccd ECR registry. The script assumes you have valid aws credentials stored in a profile named `ecr-live1`.

```bash
$ cd .../cccd-migrator
$ .k8s/build.sh
```

## Deploy
The docker image is intended to be deployed as a container in a standalone pod
within the namespace hosting the destination s3 bucket and RDS instance. e.g. cccd-dev

```bash
# deploy master branch cccd-template-deploy-migrator to the cccd-dev namespace
$ cd .../cccd-migrator
$ .k8s/deploy.sh dev
```

```bash
# deploy a branch of cccd-template-deploy-migrator to the cccd-dev namespace
$ cd .../cccd-migrator
$ .k8s/deploy.sh dev <my-branch>-latest|<commit-sha>
```

There is a cronjob that can be applied to schedule unattended s3 sync:
```bash
# apply the cronjob for syncing s3 between cccd-dev namespace's s3 bucket and TD dev's s3 bucket
$ cd .../cccd-migrator
$ .k8s/sync_s3_cronjob.sh dev
```

## Run

### S3
It is intended that the migration task be run once via the pod and, thereafter, as a cronjob. The cronjob synchronizes the live-1 s3 bucket synchronized with template-deploy every hour.

Note that the wrapped `aws s3 sync` command includes the `--delete` option. This will delete objects in destination that do not exist in source.

Output cli help:
```bash
bin/migrate -h
```

Produce a summary report of source and destination objects:
```bash
bin/migrate s3 --report -ym
```

Synchronize destination with source:
```bash
bin/migrate s3 --sync -ym
```

Delete all objects in destination bucket, for testing purposes only:
```bash
bin/migrate s3 --empty -ym
```
_note: `--sync` option deletes objects in destination that are not in source. So `--empty` is purely for testing purposes_


### RDS
The "migration" of a single postgres database can be achieved using this utility.

The CLI will:

 - drop the existing `destination` database
 - create an empty `destination` database with the same name
 - produce plain text dump files from the `source` database
 - apply those dump files to the empty database

Recreate destination database using source database:
```bash
$ bin/migrate rds --sync -ym
```

## Setup
In order for the CLI to function as intended several setup steps are required

### Destination (live-1) s3 bucket IAM user policy.

The IAM user of the s3 destination bucket must have a policy that includes the actions and resources necessary for listing and object actions fors its own bucket AND that of the source

```
# example user policy for terraform file - s3.tf
  user_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
    "Sid": "",
    "Effect": "Allow",
    "Action": [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ],
    "Resource": [
      "$${bucket_arn}",
      "arn:aws:s3:::example-source-bucket-name"
    ]
  },
  {
    "Sid": "",
    "Effect": "Allow",
    "Action": [
      "s3:*"
    ],
    "Resource": [
      "$${bucket_arn}/*",
      "arn:aws:s3:::example-source-bucket-name/*"
    ]
  }
]
}
EOF
```

### Source (Template-deploy) bucket policy.

The source (template-deploy) s3 bucket must have a bucket policy that
allows the destination s3 user to list bucket and read/copy objects.

To do this you must first retrieve the destination s3 users ARN for use in the source bucket policy

```bash
# retrieve destination s3 user ARN
$ unset AWS_PROFILE ; read K a n S <<<$(kubectl -n my-namespace get secret my-s3-secrets -o json | jq -r '.data[] | @base64d') ; export AWS_ACCESS_KEY_ID=$K ; export AWS_SECRET_ACCESS_KEY=$S ; aws sts get-caller-identity
```

You should get output similar to below:
```json
{
"UserId": "<ALPHANUMERIC>",
"Account": "<LONG-INTEGER>",
"Arn": "arn:aws:iam::<LONG_INTEGER>:<dir-structure-from-cloud-platforms>-<alphanumeric>"
}
```

You can then create a bucket policy on the source bucket you are wanting to sync (copy) data from.


```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCccdSourceBucketAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::<user-id-from-sts-output>"
            },
            "Action": [
                "s3:ListBucket",
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::example-source-bucket",
                "arn:aws:s3:::example-source-bucket/*"
            ]
        }
    ]
}
```

Note: these settings limit the destination IAM users actions and resource access to list, get and copy type actions only on the source bucket.