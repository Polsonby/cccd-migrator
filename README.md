# CCCD Migrator

Ruby cli that wraps calls to aws cli commandline utility for s3 synchronization
between template deploy environment's s3 buckets (source) and live-1 s3 buckets (destination).

## Build
To build the docker image using the provided script you will need credentials for accessing live-1 cccd ECR registry. The script assumes you have valid aws credentials stored in a profile named `ecr-live1`.

```bash
$ cd .../cccd-migrator
$ .k8s/build.sh
```

## Deploy
The docker image is intended to be deployed as a container in a standalone pod
within the namespace hosting the destination s3 bucket. e.g. cccd-dev

The [https://github.com/ministryofjustice/Claim-for-Crown-Court-Defence](Claim-for-Crown-Court-Defence) repo holds a migrator/pod.yaml (config) and migrator/deploy.sh (script) to achieve this.

```bash
# example of deploying the cccd-template-deploy-migrator to the cccd-dev namespace
$ cd .../Claim-for-Crown-Court-Defence
$ kubernetes_deploy/pods/migrator/deploy.sh dev
```

There is also a cronjob that can be applied to schedule unattended s3 sync:
```bash
$ cd .../Claim-for-Crown-Court-Defence
$ kubernetes_deploy/pods/migrator/sync_s3_cronjob.sh dev
```

## Run
It is intended that the migration task be run as a cronjob after an initial sync in order to keep the template-deploy and live-1 buckets synchronized.

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

## Setup
In order for the cli to function as intended several setup steps are required

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