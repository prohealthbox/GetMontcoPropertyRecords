require_relative '../query.rb'

module Owner

  class Query < Search::Query
    def initialize
      super

      @query_mode = 'owner'
      @mode_validation_string = 'Name'
      @query_field = 'inpOwner'
    end
  end

end
