require 'optparse'
require 'optparse/time'
require 'ostruct'
require 'pp'

def interpret_date(str)
  str.strip!
  begin
    dt = nil
    if str =~ %r{\A[0-3][0-9]-[A-Z][A-Z][A-Z]-[0-9][0-9]\Z}i
      dt = Date.strptime(str, "%d-%b-%y")
    elsif str =~ %r{\A[0-1][0-9]/[0-3][0-9]/[1-2][0-9][0-9][0-9]\Z}i
      dt = Date.strptime(str, "%m/%d/%Y")
    elsif str =~ %r{\A[0-1][0-9]-[0-3][0-9]-[1-2][0-9][0-9][0-9]\Z}i
      dt = Date.strptime(str, "%m-%d-%Y")
    elsif str =~ %r{\A[2-3][0-9]/[0-3][0-9]/[1-2][0-9][0-9][0-9]\Z}i
      dt = Date.strptime(str, "%d/%m/%Y")
    else
      dt = Date.parse(str)
    end
    dt = dt.prev_year(100) if dt > Date.today

    return dt
  rescue
    nil
  end
end

class OptionParser

  TABLES = %w[properties assessment_histories sales_histories residential_cards]
  TABLE_ALIASES = { 'parcel' => 'properties', 'property' => 'properties' }

  #
  # Return a structure describing the options.
  #
  def self.parse(args)
    # The options specified on the command line will be collected in *options*.
    # We set default values here.
    options = OpenStruct.new
    options.first_municipality = 1
    options.last_municipality = 67
    options.lower_bounds = '010000000000'
    options.upper_bounds = '679999999999'
    options.parcel_pattern = '.*'
    options.verbose = false
    options.do_sequence = false
    options.do_update_parcel = false
    options.do_update_since_last_time = false
    options.do_update_remaining = false
    options.do_update_from = false
    options.do_sales_histories = false
    options.do_custom = false
    options.parcel_expressions = []
    options.update_parcels = []
    options.save_tables = Hash.new(false)
    options.start_date = nil
    options.limit = -1

    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0.sub(/.*[\\\/]/, '').sub(/\.[^.]*/, '')} [options]"

      opts.separator ''
      opts.separator 'Specific options:'

      opts.on('--first-municipality CODE', 'Specify the first municipality CODE for sequencing') do |num|
        options.first_municipality = num
        # TODO: fail if code < 1
      end

      opts.on('--last-municipality CODE', 'Specify the last municipality CODE for sequencing') do |num|
        options.last_municipality = num
        # TODO: fail if code > 67
        # TODO: fail if code < first_municipality
      end

      opts.on('-A', '--lower-bounds ID', 'Specify the lower bounds for the parcel ID') do |id|
        options.lower_bounds = id
      end

      opts.on('-Z', '--upper-bounds ID', 'Specify the upper bounds for the parcel ID') do |id|
        options.upper_bounds = id
      end

      opts.on('-p', '--pattern REGEXP', 'Only process parcels matching the REGEXP') do |regexp|
        options.parcel_pattern = regexp
      end

      opts.on('-l', '--limit NUM', 'Limit the NUMber of parcels updates') do |num|
        options.limit = num.to_i
      end

      opts.on('-s', '--sequence [EXPR,EXPR,EXPR,...]', Array,
              'Sequence through all parcel numbers to identify all parcels',
              '  (within the prefix specified by the list of parcel EXPRessions if supplied)') do |exprs|
        options.parcel_expressions = exprs
        options.do_sequence = true
      end

      opts.on('-u', '--update-parcel [PARCEL_ID,PARCEL_ID,...]', Array,
              'Sequence through all parcel numbers to identify all parcels',
              '  (within the prefix specified by the list of parcel expressions if supplied)') do |parcel_ids|
        options.update_parcels = parcel_ids
        options.do_update_parcel = true
      end

      opts.on('-U', '--update-since-last', 'Update all parcels since the last update run (minus 10 days)') do
        options.do_update_since_last_time = true
      end

      opts.on('-f', '--update-from DATE', 'Update all parcels since the given DATE') do |date|
        options.do_update_from = true
        options.start_date = interpret_date(date)
      end

      opts.on('--update-remaining', 'Update all parcels that are not complete') do
        options.do_update_remaining = true
      end

      opts.on('--update-sales-histories', 'Update all sales histories that are not complete') do
        options.do_sales_histories = true
      end

      opts.on('--custom', 'Perform a custom lookup and update of parcels') do
        options.do_custom = true
      end

      table_list = (TABLE_ALIASES.keys + TABLES).join(',')
      opts.on('-S', '--save TABLE', TABLES, TABLE_ALIASES, 'table to save when updating',
              "  (#{table_list})") do |table|
        options.save_tables[table.to_sym] = true
      end

=begin
      # Cast 'delay' argument to a Float.
      opts.on('--delay N', Float, 'Delay N seconds before executing') do |n|
        options.delay = n
      end

      # Cast 'time' argument to a Time object.
      opts.on('-t', '--time [TIME]', Time, 'Begin execution at given time') do |time|
        options.time = time
      end

      # Cast to octal integer.
      opts.on('-F', '--irs [OCTAL]', OptionParser::OctalInteger,
              'Specify record separator (default \\0)') do |rs|
        options.record_separator = rs
      end

      # List of arguments.
      opts.on('--list x,y,z', Array, 'Example "list" of arguments') do |list|
        options.list = list
      end

      # Keyword completion.  We are specifying a specific set of arguments (CODES
      # and CODE_ALIASES - notice the latter is a Hash), and the user may provide
      # the shortest unambiguous text.
      code_list = (CODE_ALIASES.keys + CODES).join(',')
      opts.on('--code CODE', CODES, CODE_ALIASES, 'Select encoding',
              "  (#{code_list})") do |encoding|
        options.encoding = encoding
      end

      # Optional argument with keyword completion.
      opts.on('--type [TYPE]', [:text, :binary, :auto],
              'Select transfer type (text, binary, auto)') do |t|
        options.transfer_type = t
      end

=end
      opts.separator ''
      opts.separator 'Common options:'

      # No argument, shows at tail.  This will print an options summary.
      # Try it and see!
      opts.on_tail('-h', '--help', 'Show this message') do
        puts opts
        exit
      end

      # Boolean switch.
      opts.on('-v', '--[no-]verbose', 'Show messages indicating progress') do |v|
        options.verbose = v
      end

      # Another typical switch to print the version.
      opts.on_tail('--version', 'Show version') do
        puts ::Version.join('.')
        exit
      end
    end

    opt_parser.parse!(args)
    options
  end  # parse()

end  # class OptionParser