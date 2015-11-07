module DB

  class SalesHistory < MontcoBase
    def initialize
      @table = 'sales_histories'
      # @records_to_complete_sql = %Q{
      #   SELECT p.parcel_id
      #   FROM properties p
      #   LEFT JOIN #{@table} h on h.parcel_id = p.parcel_id
      #   WHERE h.parcel_id IS NULL}
      @records_to_complete_sql = %Q{
        SELECT distinct parcel_id
        FROM #{@table} h
        WHERE sale_date IS NULL OR date_recorded is NULL}
    end
  end

end
