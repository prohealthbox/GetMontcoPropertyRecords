require_relative 'montco_base'

module DB

  class Property < MontcoBase
    def initialize
      @table = 'properties'
      @records_to_complete_sql = %Q{
        SELECT parcel_id
        FROM #{@table}
        WHERE land_use_code != 1101 and land_use_description = 'R - SINGLE FAMILY'}
    end
  end

end
