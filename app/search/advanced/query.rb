require_relative '../query.rb'

module Advanced

  class Query < Search::Query
    def initialize
      super

      @query_mode = 'advanced'
      @mode_validation_string = 'Advanced'
      @query_field = 'hdCriteria'
    end
  end

end
