# Easy Database Backup to S3
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
```
3. Setup a cronjob running backups.rb file

