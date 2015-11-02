require_relative '../query'

module Parcel

  ID_LENGTH = 12

  class Query < Search::Query
    def initialize
      super

      @query_mode = 'parid'
      @mode_validation_string = 'Parcel ID'
      @query_field = 'inpParid'
    end
  end

end