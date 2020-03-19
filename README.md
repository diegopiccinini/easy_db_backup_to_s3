# Easy Database Backup to S3
## Description
Easy way to upload sql.gz files to S3 bucket with this structure:
 - clustername/year/month/mday/hour/database_name.sql.gz

## Requirements
Install aws console command, and add the credentials to the user in order to upload to s3 bucket.
## Ruby Version
~> 2.3
## Steps

1. clone the repository and install rvm ruby 2.5.0

   1.1.

   ```bash
   cd easy_db_backup_to_s3/
   gem install bundler
   bundle install
   ```
   1.2. Create a DynamoDb called *backups* with partition key (String) *database* and sort key (Number) *datehour*

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

Create a bash script *backups.sh*

```bash
# execution mode
chmod 700 backups.sh
```

```bash
# sample with rvm and easy_db_backup_to_s3 in ~ directory
cd ~/easy_db_backup_to_s3 && ~/.rvm/wrappers/ruby-2.5.0/ruby backups.rb > log/backups.log
```
Cronjobs
```bash
5 2 * * * ~/backups.sh 2>&1
```

4. Test

Create a bash script *tests.sh*

```bash
# execution mode
chmod 700 test.sh
```

```bash
# sample with rvm and easy_db_backup_to_s3 in ~ directory
cd ~/easy_db_backup_to_s3 && ~/.rvm/wrappers/ruby-2.5.0/ruby test.rb > log/backups.log
```
Cronjobs
```bash
# here in my sample is 1 hour after the last backup
# the test will store in DynamoDB the result of the restore process in the same cluster + _test in the name of the original database.
5 3 * * * ~/test.sh 2>&1
```


5. Restore
```bash
ruby restore.rb
```
It will show the list of database engines and databases to choose and restore.
