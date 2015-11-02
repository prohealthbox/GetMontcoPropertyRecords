require_relative 'montco_base'

module DB

  class Property < MontcoBase
    def initialize
      @table = 'properties'
      @records_to_complete_sql = %Q{
        SELECT parcel_id
        FROM #{@table}
        WHERE municipality IS NULL}
    end
  end

end
