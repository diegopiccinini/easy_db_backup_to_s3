#!/usr/bin/ruby

require 'date'
require 'yaml'

Dir.glob(File.join('.', 'lib', '**', '*.rb'), &method(:require))

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
  dynamo = Database.new
  conns, dbs = data['conns'], data['dbs']
  hour = make_dirs(conns)
  hourint = hour.gsub('/','')
  dbs.each_pair do |db, conn|
    conn_data = conns[conn]
    s = conn_data.each_pair.map { |k, v| "-#{k}#{v}" }
    file = "#{BASEDIR}/#{conn}/#{hour}/#{db}.sql"
    s = "mysqldump #{s.join(' ')} --skip-dump-date --skip-comments #{db} > #{file}"
    final_tasks(s, file)
    dynamo.item(db, hourint, false)
  end
end

def md5(file)
  system "md5sum #{file} > #{file}.md5sum"
end

def gpg(file)
  system "gpg --encrypt --sign --armor -r #{$gpg_email} #{file}"
end

def final_tasks(s, file)
  system s
  md5(file)
  gpg(file)
  md5("#{file}.asc")
  system "gzip #{file}.asc"
  system "rm #{file}"
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
    final_tasks(s, file)
  end
end

def main
  data = YAML.load_file "#{PROJECT_DIR}/config/databases.yml"
  $gpg_email = data['gpg_email']
  backups(data['mysql'])
  pg_backups(data['postgreSQL'])
  upload_and_remove
end

main

