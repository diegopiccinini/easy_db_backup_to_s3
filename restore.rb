#!/usr/bin/ruby

require 'date'
require 'yaml'

Dir.glob(File.join('.', 'lib', '**', '*.rb'), &method(:require))

PROJECT_DIR = "#{File.expand_path(__dir__)}"
BASEDIR = "#{PROJECT_DIR}/restore"

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

def restore(data)
  conns = data[engine]['conns']
  db_conn = $dbs[engine][$db]
  db = db_conn['db']
  conn = db_conn['conn']
  key = "#{conn}|#{db}"
  $item = $dynamo.last(key)
  dir = make_dir(conn, db)
  db_base = "#{conn}/#{hour}/#{db}"
  download(db_base, db, dir)
  file = "#{dir}/#{db}.sql.asc"
  system "gzip -d #{file}.gz"
  raise "checksum of #{file} error" unless checkmd5(file)
  gpg(file)
  file = "#{dir}/#{db}.sql"
  raise "checksum of #{file} error" unless checkmd5(file)
  conn_data = conns[conn]
  mysql_restore(conn_data, db, file) if engine == 'mysql'
  pg_restore(conn_data, db, file) if engine == 'postgreSQL'
end

def mysql_restore(conn_data, db , file)
  s = conn_data.each_pair.map { |k, v| "-#{k}#{v}" }
  `mysql #{s.join(' ')} -e 'DROP DATABASE IF EXISTS #{db}; CREATE DATABASE #{db};'`
  `mysql #{s.join(' ')} --comments #{db} < #{file}`
  `mysqldump #{s.join(' ')} --skip-dump-date --skip-comments #{db} > #{file}.test`
  puts checkmd5(file, "#{file}.test") ? 'restore test passed' : 'restore test failed'
end

def pg_restore(conn_data, db , file)
  conn = "PGPASSWORD=#{conn_data['password']} psql -U#{conn_data['U']}"
  conn << " -h#{conn_data['h']} " if conn_data.has_key?('h')
  s = "#{conn} #{db} -c 'DROP DATABASE IF EXISTS restore_conn_db;' "
  system s
  s = "#{conn} #{db} -c 'CREATE DATABASE restore_conn_db;' "
  system s
  s = "#{conn} restore_conn_db -c 'DROP DATABASE #{db}; ' "
  system s
  s = "#{conn} restore_conn_db -c 'CREATE DATABASE #{db};' "
  system s
  s = "#{conn} #{db} < #{file}"
  system s
  s = "#{conn} #{db} -c 'DROP DATABASE IF EXISTS restore_conn_db;' "
  system s

  s = "PGPASSWORD=#{conn_data['password']} pg_dump -o -U#{conn_data['U']}"
  s << " -h#{conn_data['h']} " if conn_data.has_key?('h')
  s << " -d#{db} > #{file}.test"
  system s
  system "sort #{file} > #{file}.sort"
  system "sort #{file}.test > #{file}.test.sort"
  puts checkmd5_two(file, "#{file}.test") ? 'restore test passed' : 'restore test failed'
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

def list_dbs(data)
  list(data['mysql'], 'mysql') if data.has_key?('mysql')
  list(data['postgreSQL'], 'postgreSQL') if data.has_key?('postgreSQL')
end

def list(data, db_engine)
  puts
  puts 'Restore script, list of databases:'
  puts
  puts "#{$db_engine.count}. #{db_engine}"
  $db_engine << db_engine
  $dbs[db_engine] = []
  data['dbs'].each do |db_conn|
    db = db_conn['db']
    conn = db_conn['conn']
    puts "\t#{$dbs[db_engine].count}. #{db} (cluster: #{conn})"
    $dbs[db_engine] << db_conn
  end
  puts
end

def select_db_type
  puts 'Type database type number or another char to exit'
  $db_engine.each_with_index { |v, k| puts "#{k}. #{v}" }
  $engine = gets.chomp
  if $engine.to_i.to_s == $engine
    $engine = $engine.to_i
    exit if $engine > $db_engine.count
  else
    exit
  end
  puts "Type: #{$db_engine[$engine]}"
end

def select_db
  puts 'Type database number or another char to exit'
  $dbs[engine].each_with_index { |v, k| puts "#{k}. #{v}" }
  $db = gets.chomp
  if $db.to_i.to_s == $db
    $db = $db.to_i
    exit if $db > $dbs[engine].count
  else
    exit
  end
  puts "Database: #{$dbs[engine][$db]}"
end

def engine
  $db_engine[$engine]
end

def main
  data = YAML.load_file "#{PROJECT_DIR}/config/databases.yml"
  $db_engine = []
  $dbs = {}
  list_dbs(data)
  select_db_type
  select_db
  $s3_bucket = data['s3_bucket']
  $dynamo = Database.new
  restore(data)
  system "rm -rf #{BASEDIR}/*"
end

main

