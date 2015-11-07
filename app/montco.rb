require 'active_support'
require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/numeric'
require_relative 'option_parser'
require_relative 'sequencer'
require_relative 'get_details'

begin # if __FILE__ == $0
  Options = OptionParser.parse(ARGV)

  Sequencer.invoke if Options.do_sequence

  GetDetails.update_parcel if Options.do_update_parcel
  GetDetails.update_since_last_time if Options.do_update_since_last_time
  GetDetails.update_remaining if Options.do_update_remaining
  GetDetails.update_from if Options.do_update_from
  GetDetails.update_custom if Options.do_custom
  GetDetails.update_sales_histories if Options.do_sales_histories
end