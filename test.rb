#!/usr/bin/ruby

require 'date'
require 'yaml'

Dir.glob(File.join('.', 'lib', '**', '*.rb'), &method(:require))

PROJECT_DIR = "#{File.expand_path(__dir__)}"
BASEDIR = "#{PROJECT_DIR}/tests"
S3_BUCKET = 'prod-databases-backups'

def make_dir(conn, db)
  `mkdir #{BASEDIR}` unless Dir.exist?(BASEDIR)
  dir = "#{BASEDIR}/#{conn}/#{db}"
  `mkdir -p #{dir}`
  dir
end

def backups(data)
  conns, dbs = data['conns'], data['dbs']
  dbs.each_pair do |db, conn|
    item = $dynamo.last(db)
    p item
    datehour = item['datehour'].to_i.to_s
    hour = "#{datehour[0..3]}/#{datehour[4..5]}/#{datehour[6..7]}/#{datehour[8..9]}"
    dir = make_dir(conn, db)
    db_base = "#{conn}/#{hour}/#{db}"
    download(db_base, db, dir)
    system "gzip -d #{dir}/#{db}.sql.asc.gz"
    file = "#{dir}/#{db}.sql.asc"
    checkmd5(file)
    gpg(file)
    file = "#{dir}/#{db}.sql"
    checkmd5(file)
    conn_data = conns[conn]
    s = conn_data.each_pair.map { |k, v| "-#{k}#{v}" }
    `mysql #{s.join(' ')} -e 'CREATE DATABASE #{db}_test;'`
    `mysql #{s.join(' ')} #{db}_test < #{file}`
    `mysqldump #{s.join(' ')} --skip-dump-date --skip-comments #{db}_test > #{file}.test`
    `mysql #{s.join(' ')} -e 'DROP DATABASE #{db}_test;'`
    if checkmd5(file, "#{file}.test")
      $dynamo.item(item['database'], item['datehour'], true)
    end
  end
end

def md5(file)
  system "md5sum #{file} > #{file}.md5sum"
end

def gpg(file)
  system "gpg --decrypt #{file}"
end

def final_tasks(s, file)
  system s
  md5(file)
  gpg(file)
  md5("#{file}.asc")
  system "gzip #{file}.asc"
  system "rm #{file}"
end

def download(db_base, db, dir)
  system "/usr/local/bin/aws s3 cp s3://#{S3_BUCKET}/#{db_base}.sql.asc.md5sum #{dir}/#{db}.sql.asc.md5sum"
  system "/usr/local/bin/aws s3 cp s3://#{S3_BUCKET}/#{db_base}.sql.asc.gz #{dir}/#{db}.sql.asc.gz"
  system "/usr/local/bin/aws s3 cp s3://#{S3_BUCKET}/#{db_base}.sql.md5sum #{dir}/#{db}.sql.md5sum"
end

def checkmd5(file, origin = nil)
  a = `md5sum #{origin || file}`
  b = `cat #{file}.md5sum`
  raise "md5sum error #{file}" unless a.split.first == b.split.first
end

def pg_backups(data)
  dbs.each_pair do |db, conn|
    item = $dynamo.last(db)
    p item
  end
end

def main
  data = YAML.load_file "#{PROJECT_DIR}/config/databases.yml"
  $dynamo = Database.new
  backups(data['mysql'])
  #pg_backups(data['postgreSQL'])
  system "rm -rf #{BASEDIR}/*"
end

main

