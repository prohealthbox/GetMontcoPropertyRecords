require_relative 'search/parcel/query'
require_relative 'db/property'
require_relative 'db/assessment_history'
require_relative 'db/sales_history'
require_relative 'db/residential_card'

class FormatError < StandardError
end

class GetDetails
  CHUNK_SIZE = 100

  def initialize
    @parcels = Parcel::Query.new
    @properties = DB::Property.new
    @assessment_histories = DB::AssessmentHistory.new
    @sales_histories = DB::SalesHistory.new
    @residentials = DB::ResidentialCard.new
  end

  def update_one(parcel_id)
    raise FormatError, "parcel id format is incorrect for #{parcel_id}" unless parcel_id =~ /\A\d{12}\Z/

    # Profile tab
    parcels = @parcels.find(parcel_id)
    @properties.save(parcels) if parcels.length > 0

    # Assessment History tab
    assessments = @parcels.find_assessment_history(parcel_id)
    @assessment_histories.save(assessments) if assessments.length > 0

    # Sales History tab
    sales = @parcels.find_sales_history(parcel_id)
    @sales_histories.save(sales) if sales.length > 0

    # Residential tab
    residentials = @parcels.find_residential(parcel_id)
    @residentials.save(residentials) if residentials.length > 0
  end

  # find one parcel at a time, extracting all the details and saving to the database
  def update_details
    props = @properties.records_to_complete(CHUNK_SIZE)
    while props do
      props.each do |parcel_id|
        retry_attempts = 0
        begin
         update_one parcel_id
        rescue URLError => error
          retry_attempts += 1
          if retry_attempts <= 6
            puts "#{error.class}: #{error.message}\nIssue trying to update details for parcel id #{parcel_id}, retry attempt #{retry_attempts}/6"
            @parcels.disconnect   # will reconnect on next attempt
            sleep 5
            retry
          else
            puts "Failed trying to update details for parcel id #{parcel_id}"
          end
        rescue => error
          retry_attempts += 1
          if retry_attempts <= 2
            puts "#{error.class}: #{error.message}\nIssue trying to update details for parcel id #{parcel_id}, retry attempt #{retry_attempts}/6"
            @parcels.disconnect   # will reconnect on next attempt
            sleep 5
            retry
          else
            puts "Failed trying to update details for parcel id #{parcel_id}"
          end
        end
      end
      props = @properties.records_to_complete(CHUNK_SIZE)
    end
  end

end

det = GetDetails.new
if ARGV.count > 0
  ARGV.each do |parcel_id|
    det.update_one parcel_id
  end
else
  det.update_details
end
