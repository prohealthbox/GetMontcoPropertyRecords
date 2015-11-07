require 'mysql2'
require 'active_support/inflector'  # for pluralize
require_relative 'montco_base'

module DB
  @client = Mysql2::Client.new(host: 'localhost', username: 'montco', password: 'slurpee', database: 'montco')

  def self.client
    @client
  end

  class MontcoBase
    def save(records)
      sql = "INSERT INTO #{@table} ("
      records[0].keys.map { |fld| field_mapper(fld) }.each { |fld|
        sql = sql + " #{fld},"
      }
      sql.chomp!(',')
      sql += ' ) VALUES ('
      records[0].keys.each { |fld|
        sql = sql + ' ?,'
      }
      sql.chomp!(',')
      sql = sql + ' )' + "\n  ON DUPLICATE KEY UPDATE"
      records[0].keys.map { |fld| field_mapper(fld) }.each { |fld|
        sql = sql + " #{fld} = VALUES(#{fld}),"
      }
      sql.chomp!(',')

      statement = DB.client.prepare(sql)
      records.each { |record|
        statement.execute(*(record.values))
      }
      parcels = records.map { |rec| rec[:parcel_id] }.uniq
      puts "saved #{records.length} #{@table}; " + 'parcel'.pluralize(parcels.length) + ': ' + parcels.join(', ')
    end

    # return a list of parcel ids for those records that still need the details updated
    def records_to_complete(limit = nil)
      sql = @records_to_complete_sql.strip
      sql += " LIMIT 0, #{limit};" unless limit.nil?

      DB.client.query(sql, symbolize_keys: true).map { |row| ('0' + row[:parcel_id].to_s)[-12..-1] }
    end

    protected

    def field_mapper(fld)
      case fld
        when :sales_date
          :sold_date
        when :sales_amount
          :sold_amount
        when :luc
          :land_use_code
        when :property_address
          :address
        when :altid
          :alt_id
        else
          fld
      end
    end

    private

    def initialize
      @table = 'unknown'
    end

  end

end
