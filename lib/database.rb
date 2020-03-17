# frozen_string_literal: true

require 'aws-sdk-dynamodb'

# dynamoDB connection to push and get items
class Database
  TABLE_NAME = 'backups'
  attr_accessor :table, :result
  def initialize
    client = Aws::DynamoDB::Client.new
    @table = Aws::DynamoDB::Table.new('backups', client)
  end

  def item(db, datehour, tested = nil, extra_data = {})
    key = { database: db, datehour: datehour }
    tested.nil? ? read(key) : write(key, tested, extra_data)
  end

  def last(db)
    sort(db, false).items.first
  end

  def first(db)
    sort(db).items.first
  end

  def update_item(k, extra_vars)
    @table.update_item({ key: { 'database' => k['database'], 'datehour' => k['datehour'] },
                         attribute_updates: extra_vars })
  end

  private

  def read(key)
    @result = table.get_item(
      key: key,
      attributes_to_get: ['tested', 'updated_at'],
      consistent_read: true
    )
  end

  def write(key, tested = false, extra_data = {})
    @result = table.put_item(
      item: {
        'database' => key[:database],
        'datehour' => key[:datehour],
        'tested' => tested,
        'updated_at' => DateTime.now.to_s
      }.merge(extra_data)
    )
  end

  def query(db)
    {
      limit: 1,
      key_condition_expression: "#db = :db",
      expression_attribute_names: {
        "#db" => "database",
      },
      expression_attribute_values: {
        ":db" => db
      }
    }
  end

  def sort(db, asc = true)
    table.query(query(db).merge(scan_index_forward: asc))
  end
end
