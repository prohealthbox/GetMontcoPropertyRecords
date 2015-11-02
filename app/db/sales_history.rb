module DB

  class SalesHistory < MontcoBase
    def initialize
      @table = 'sales_histories'
      @records_to_complete_sql = %Q{
        SELECT p.parcel_id
        FROM properties p
        LEFT JOIN #{@table} h on h.parcel_id = p.parcel_id
        WHERE h.parcel_id IS NULL}
    end
  end

end
