#!/usr/bin/ruby

require 'date'
require 'yaml'

PROJECT_DIR = "#{File.expand_path(__dir__)}"
BASEDIR = "#{PROJECT_DIR}/backups"
S3_BUCKET = 'prod-databases-backups'

def make_dirs(conns)
  `mkdir #{BASEDIR}` unless Dir.exist?(BASEDIR)
  hour = DateTime.now.strftime '%Y/%m/%d/%H'
  dirs = conns.keys.map { |x| "#{BASEDIR}/#{x}/#{hour}" }
  dirs.each { |x| `mkdir -p #{x}` }
  hour
end

def backups(data)
  conns, dbs = data['conns'], data['dbs']
  hour = make_dirs(conns)
  dbs.each_pair do |db, conn|
    conn_data = conns[conn]
    s = conn_data.each_pair.map { |k, v| "-#{k}#{v}" }
    file = "#{BASEDIR}/#{conn}/#{hour}/#{db}.sql"
    s = "mysqldump #{s.join(' ')} #{db} > #{file}"
    system s
    system "gzip #{file}"
  end
end

def upload_and_remove
  system "/usr/local/bin/aws s3 sync #{BASEDIR} s3://#{S3_BUCKET}"
  system "rm -rf #{BASEDIR}/*"
end

def pg_backups(data)
  conns, dbs = data['conns'], data['dbs']
  hour = make_dirs(conns)
  dbs.each_pair do |db, conn|
    conn_data = conns[conn]
    file = "#{BASEDIR}/#{conn}/#{hour}/#{db}.sql"
    s = "PGPASSWORD=#{conn_data['password']} pg_dump -U#{conn_data['U']} -h#{conn_data['h']} -d#{db} > #{file}"
    system s
    system "gzip #{file}"
  end
end

def main
  data = YAML.load_file "#{PROJECT_DIR}/config/databases.yml"
  backups(data['mysql'])
  pb_backups(data['postgreSQL'])
  upload_and_remove
end

main

