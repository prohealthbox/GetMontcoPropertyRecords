require_relative 'search/parcel/query'
require_relative 'db/property'
require_relative 'db/update_history'

#
# First sequence starts with 01
# Last sequence starts with 67
#
class Sequencer

  class << self
    def invoke
      seq = Sequencer.new

      expressions = Options.parcel_expressions || []

      seq.municipalities do |municipality|
        expressions << municipality
      end if expressions.empty?

      # Sequence through all municipalities and walk through the parcels in each
      start_id = DB::UpdateHistory.mark('sequencer_start')

      expressions.each do |expr|
        puts "Sequencing through parcels beginning with #{expr}" if Options.verbose
        seq.query expr
      end

      DB::UpdateHistory.mark('sequencer_complete', start_id)
    end
  end

  def initialize
    @parcels = Parcel::Query.new
    @properties = DB::Property.new
  end

  def municipalities
    (Options.first_municipality..Options.last_municipality).each do |s|
      yield ('0' + s.to_s)[-2..-1]
    end
  end

  def parcels_decreasing(partial)
    ids = @parcels.find_ids(partial, 1)

    return [@parcels.total_records_found, ids[0]]
  end

  def save(parcels)
    @properties.save(parcels)
  end

  # walk down the partial parcel id and gather the existing parcels starting with this partial
  def query(partial)
    (cnt, max_id) = parcels_decreasing(partial)
    puts "query: '#{partial}' --> cnt: #{cnt}; max: #{max_id}\n"

    if cnt == 0                                           # no more to process/save
      return false                                        # exhaustive search is complete on this partial
    elsif cnt <= Search::MAX_RECORDS                      # we are done processing this partial as there are fewer than max_records results
      parcels = @parcels.find(partial)
      save(parcels)

      return false                                        # exhaustive search is complete on this partial
    elsif max_id =~ /^(#{partial}0*[1-9])/                # eat a run of zeros and find next sub-partial
      sub_partial = $1
      while query(sub_partial)  || sub_partial[-1] > '0'  # can we complete this sub-partial? (<= max records?)
        # find next sub-partial and walk it down
        sub_partial = sub_partial[0..-2] + (sub_partial[-1].to_i-1).to_s
      end
    end

    return false
  end

end