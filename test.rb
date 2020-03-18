#!/usr/bin/ruby

require 'date'
require 'yaml'

Dir.glob(File.join('.', 'lib', '**', '*.rb'), &method(:require))

PROJECT_DIR = "#{File.expand_path(__dir__)}"
BASEDIR = "#{PROJECT_DIR}/tests"

def make_dir(conn, db)
  `mkdir #{BASEDIR}` unless Dir.exist?(BASEDIR)
  dir = "#{BASEDIR}/#{conn}/#{db}"
  `mkdir -p #{dir}`
  dir
end

def hour
  datehour = $item['datehour'].to_i.to_s
  "#{datehour[0..3]}/#{datehour[4..5]}/#{datehour[6..7]}/#{datehour[8..9]}"
end

def backups(data, restore = 'mysql')
  conns, dbs = data['conns'], data['dbs']
  dbs.each_pair do |db, conn|
    $item = $dynamo.last(db)
    dir = make_dir(conn, db)
    db_base = "#{conn}/#{hour}/#{db}"
    download(db_base, db, dir)
    file = "#{dir}/#{db}.sql.asc"
    system "gzip -d #{file}.gz"
    update_item('md5sum_match_asc_file', true) if checkmd5(file)
    gpg(file)
    file = "#{dir}/#{db}.sql"
    update_item('md5sum_match_sql_file', true) if checkmd5(file)
    conn_data = conns[conn]
    db_test = "#{db}_test"
    mysql_restore(conn_data, db_test, file) if restore == 'mysql'
    pg_restore(conn_data, db_test, file, db) if restore == 'pg'
  end
end

def mysql_restore(conn_data, db , file)
  s = conn_data.each_pair.map { |k, v| "-#{k}#{v}" }
  `mysql #{s.join(' ')} -e 'CREATE DATABASE #{db};'`
  `mysql #{s.join(' ')} --comments #{db} < #{file}`
  `mysqldump #{s.join(' ')} --skip-dump-date --skip-comments #{db} > #{file}.test`
  `mysql #{s.join(' ')} -e 'DROP DATABASE #{db};'`
  update_item('tested', true) if checkmd5(file, "#{file}.test")
end

def pg_restore(conn_data, db , file, original_db)
  conn = "PGPASSWORD=#{conn_data['password']} psql -U#{conn_data['U']}"
  conn << " -h#{conn_data['h']} " if conn_data.has_key?('h')
  s = "#{conn} #{original_db} -c 'CREATE DATABASE #{db};' "
  system s
  s = "#{conn} #{db} < #{file}"
  system s

  s = "PGPASSWORD=#{conn_data['password']} pg_dump -o -U#{conn_data['U']}"
  s << " -h#{conn_data['h']} " if conn_data.has_key?('h')
  s << " -d#{db} > #{file}.test"
  system s
  s = "#{conn} #{original_db} -c 'DROP DATABASE #{db};' "
  system s
  system "sort #{file} > #{file}.sort"
  system "sort #{file}.test > #{file}.test.sort"
  update_item('tested', true) if checkmd5_two("#{file}.sort", "#{file}.test.sort")
end

def update_item(attr, value)
  extra_vars = { attr => { value: value, action: 'PUT' } }
  $dynamo.update_item($item, extra_vars)
end

def gpg(file)
  system "gpg --decrypt #{file} > #{file[0..-5]}"
end

def download(db_base, db, dir)
  system "/usr/local/bin/aws s3 cp s3://#{$s3_bucket}/#{db_base}.sql.asc.md5sum #{dir}/#{db}.sql.asc.md5sum"
  system "/usr/local/bin/aws s3 cp s3://#{$s3_bucket}/#{db_base}.sql.asc.gz #{dir}/#{db}.sql.asc.gz"
  system "/usr/local/bin/aws s3 cp s3://#{$s3_bucket}/#{db_base}.sql.md5sum #{dir}/#{db}.sql.md5sum"
end

def checkmd5(file, testfile = nil)
  a = `md5sum #{testfile || file}`
  b = `cat #{file}.md5sum`
  a.split.first == b.split.first
end

def checkmd5_two(file, file2)
  a = `md5sum #{file}`
  b = `md5sum #{file2}`
  a.split.first == b.split.first
end
def main
  data = YAML.load_file "#{PROJECT_DIR}/config/databases.yml"
  $s3_bucket = data['s3_bucket']
  $dynamo = Database.new
  backups(data['mysql'])
  backups(data['postgreSQL'], 'pg')
  system "rm -rf #{BASEDIR}/*"
end

main

