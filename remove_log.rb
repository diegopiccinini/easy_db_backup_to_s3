#!/usr/bin/ruby

require 'date'

def remove_log
  basedir= "#{File.expand_path(__dir__)}/log"
  file = "#{basedir}/backups.log"
  lastweek = Date.today - 7
  lastweek_file = "#{file}_#{lastweek.strftime('%Y%m%d')}"
  `rm #{lastweek_file}` if File.exist?(lastweek_file)
  if File.exist?(file)
     yesterday = Date.today - 1
     yesterday_file = "#{file}_#{yesterday.strftime('%Y%m%d')}"
     `mv #{file} #{yesterday_file}` unless File.exist?(yesterday_file)
  end
end

remove_log
