require_relative 'search/parcel/query'
require_relative 'search/advanced/query'
require_relative 'db/property'
require_relative 'db/assessment_history'
require_relative 'db/sales_history'
require_relative 'db/residential_card'
require_relative 'db/update_history'

class FormatError < StandardError; end
class LimitError < StandardError; end

class GetDetails
  CHUNK_SIZE = Search::MAX_RECORDS

  class << self
    def update_parcel
      det = GetDetails.new

      Options.update_parcels.each do |parcel_id|
        det.update_one parcel_id
      end
    end

    def update_remaining
      det = GetDetails.new

      start_id = DB::UpdateHistory.mark('details_start')
      det.update_properties
      DB::UpdateHistory.mark('details_complete', start_id)
    end

    def update_since_last_time
      det = GetDetails.new

      last_start = DB::UpdateHistory.last_start('details')
      start_id = DB::UpdateHistory.mark('details_start')
      det.update_from(last_start)
      DB::UpdateHistory.mark('details_complete', start_id)
    end

    def update_from
      det = GetDetails.new

      start_id = DB::UpdateHistory.mark('details_start')
      det.update_from Options.start_date.to_time
      DB::UpdateHistory.mark('details_complete', start_id)
    end

    def update_custom
      GetDetails.new.update_custom
    end

    def update_sales_histories
      GetDetails.new.update_sales_histories
    end
  end

  def initialize
    @parcels = Parcel::Query.new
    @properties = DB::Property.new
    @assessment_histories = DB::AssessmentHistory.new
    @sales_histories = DB::SalesHistory.new
    @residentials = DB::ResidentialCard.new
    @number_updates = 0
  end

  def update_one(parcel_id)
    raise FormatError, "parcel id format is incorrect for #{parcel_id}" unless parcel_id =~ /\A\d{12}\Z/
    raise LimitError, "Maximum number of records saved (#{Options.limit})" if Options.limit > 0 && @number_updates >= Options.limit

    # Profile tab
    parcels = @parcels.find(parcel_id)
    if Options.save_tables.empty? || Options.save_tables[:properties]
      @properties.save(parcels) if parcels.length > 0
    end

    # Assessment History tab
    if Options.save_tables.empty? || Options.save_tables[:assessment_histories]
      assessments = @parcels.find_assessment_history(parcel_id)
      @assessment_histories.save(assessments) if assessments.length > 0
    end

    # Sales History tab
    if Options.save_tables.empty? || Options.save_tables[:sales_histories]
      sales = @parcels.find_sales_history(parcel_id)
      @sales_histories.save(sales) if sales.length > 0
    end

    # Residential tab
    if Options.save_tables.empty? || Options.save_tables[:residential_cards]
      residentials = @parcels.find_residential(parcel_id)
      @residentials.save(residentials) if residentials.length > 0
    end

    @number_updates += 1
  end

  def update_from(last_start=nil)
    parcels = Advanced::Query.new

    # Look for sales 10 days prior to the last start date
    # TODO: Need to sequence through dates if more than MAX_RECORDS are found
    props = parcels.find_ids('salesdate|' + (last_start - 10.days).strftime('%m/%d/%Y') + '~' + Date.today.strftime('%m/%d/%Y'), Search::MAX_RECORDS, false)

    update_details props
  end

  # find one parcel at a time, extracting all the details and saving to the database
  def update_remaining(table_type_instance)
    update_details table_type_instance.records_to_complete
  end

  def update_properties
    update_remaining @properties
  end

  def update_sales_histories
    update_remaining @sales_histories
  end

  def update_custom
  end

  def update_details(props)
    props.each do |parcel_id|
      next unless parcel_id >= Options.lower_bounds && parcel_id <= Options.upper_bounds
      next unless parcel_id =~ /#{Options.parcel_pattern}/
      retry_attempts = 0
      begin
       update_one parcel_id unless parcel_id.nil?
      rescue LimitError => error
        exit  # reached maximum number of records saved
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
  end

end
