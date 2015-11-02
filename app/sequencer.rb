require_relative 'search/parcel/query'
require_relative 'db/property'

#
# First sequence starts with 01
# Last sequence starts with 67
#
class Sequencer
  def initialize
    @parcels = Parcel::Query.new
    @properties = DB::Property.new
  end

  def municipalities
    ('01'..'67').each do |s|
      yield s
    end
  end

  def parcels_decreasing(municipality)
    (cnt, ids) = @parcels.find_ids(municipality, 1)

    return [cnt, ids[0]]
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
      (cnt, parcels) = @parcels.find(partial)
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

# Sequence through all municipalities and walk through the parcels in each
seq = Sequencer.new
seq.municipalities do |municipality|
  seq.query(municipality)
end