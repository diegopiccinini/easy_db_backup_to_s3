# Easy Database Backup to S3
## Description
Easy way to upload sql.gz files to S3 bucket with this structure:
 - clustername/year/month/mday/hour/database_name.sql.gz

## Requirements
Install aws console command, and add the credentials to the user in order to upload to s3 bucket.
## Ruby Version
~> 2.3
## Steps

1. clone the repository
2. create a config directory with a database.yml containing the connections and databases like:

```yaml
---
mysql:
  conns:
    cluster1:
      h: hostname
      p: password
      u: username
    cluster2:
      h: hostname
      p: password
      u: username
  dbs:
    database1: cluster1
    database2: cluster1
    database3: cluster2

postgreSQL:
  conns:
    cluster1:
      h: hostname
      password: password
      U: username
  dbs:
    database1: cluster1

gpg_email: email@to_sing.com
s3_bucket: name-of-the-bucket
```
3. Setup a cronjob running backups.rb file. Sample:
```bash
5 2 * * * ~/easy_db_backup_to_s3/remove_log.rb > ~/easy_db_backup_to_s3/log/remove.log 2>&1
15 2 * * * ~/easy_db_backup_to_s3/backups.rb > ~/easy_db_backup_to_s3/log/backups.log 2>&1
```
