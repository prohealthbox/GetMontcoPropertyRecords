require 'mechanize'
require 'nokogiri'
require 'date'

class URLError < StandardError
end

module Search

  MAX_RECORDS = 250
  ROOT = 'http://propertyrecords.montcopa.org/'

  class Query
    @@authenticated = false

    def find(expression, count=MAX_RECORDS, decreasing=true)
      page = results_page(expression, count, decreasing)

      case page.filename.downcase
        when /^commonsearch/
          extract_overview page
        when /^datalet/
          extract_from_profile page
        when /^errors/
          raise URLError, "Request resulted in a general error from the web server: #{page.filename}"
        else
          raise URLError, "I don't know what to do with #{page.filename}"
      end
    end

    # return the list of ids from the query
    def find_ids(expression, count=MAX_RECORDS, decreasing=true)
      ids = []
      find(expression, count, decreasing).each do |record|
        ids << record[:parcel_id]
      end

      return ids
    end

    # find the assessment history
    def find_assessment_history(parcel_id)
      page = activate_tab 'Assessment History'
      extract_assessment_history(page, parcel_id)
    end

    # find the sales history
    def find_sales_history(parcel_id)
      page = activate_tab 'Sales'
      extract_sales_history(page, parcel_id)
    end

    # find the sales history
    def find_residential(parcel_id)
      page = activate_tab 'Residential'
      extract_residential(page, parcel_id)
    end

    def disconnect
      agent.reset
      agent.shutdown
      @agent = nil
      @@authenticated = false
    end

    protected

    attr_accessor :query_mode
    attr_accessor :mode_validation_string
    attr_accessor :query_field

    private

    def initialize
      @agent = nil
      @result_limit = MAX_RECORDS
    end

    def agent
      return @agent unless @agent.nil?

      @agent = Mechanize.new { |agent|
        agent.user_agent_alias = 'Mac Safari'
        agent.follow_meta_refresh = true
      }
    end

    # Return search query string for specific search mode
    def query_string
      ROOT + 'Search/commonsearch.aspx?mode=' + query_mode
    end

    # One time authenticate to the system
    def authenticate
      return @@authenticated if @@authenticated

      page = agent.get query_string

      search_text = page.at('//td[@id="SearchText"]')
      return @@authenticated = true if search_text.text.strip.downcase.gsub(/[^a-z0-9]/, '') == mode_validation_string.downcase.gsub(/[^a-z0-9 ]/, '') unless search_text.nil?

      # get the form
      form = page.form_with(name: 'Form1')
      return @@authenticated = false if form.nil?

      # get the Agree button
      button = form.button_with(value: 'Agree')
      return @@authenticated = false if button.nil?

      # submit the form using the Agree button
      agent.submit(form, button)

      @@authenticated = true
    end

    # click the tab, returning the page
    def activate_tab(tab_name)
      page = agent.current_page
      next_page = page.at("//td[@name=\"menuCell\"]//td/a[text()='#{tab_name}']")
      next_link = Mechanize::Page::Link.new(next_page, agent, page)
      next_link.click
    end

    # query by parcel id and return the mechanized page
    def results_page(query, result_limit=@result_limit, decreasing=false)
      authenticate unless @@authenticated

      page = agent.get query_string
      results = page.form_with(name: 'frmMain') do |f|
        f.field_with(id: query_field).value = query
        f.field_with(id: 'selPageSize').value = result_limit.to_s
        f.field_with(id: 'selSortDir').value = decreasing ? 'desc' : 'asc'
        f.field_with(id: 'SortDir').value = decreasing ? 'desc' : 'asc'
      end.submit
    end

    def extract_date(element, query)
      begin Date.parse(element.xpath(query).first.inner_text.strip) rescue nil end
    end

    def extract_number(element, query)
      begin element.xpath(query).first.inner_text.strip.gsub(/[^0-9]/, '').to_i rescue 0 end
    end

    def extract_string(element, query)
      begin element.xpath(query).first.inner_text.strip rescue nil end
    end

    # given a mechanized page, extract the overview (list) records in an array of associative records
    def extract_overview(page)
      # convert the page into a usable format (nokogiri)
      html = page.body
      doc = Nokogiri::HTML(html)

      record_number = 0
      records = []
      column_names = {}

      # total_num_records = $1.to_i if doc.xpath('//font[@color="red"]').inner_text.strip =~ /Total found: (\d+) record/
      # total_num_records = doc.xpath('//span[@id="ml"][2]/following-sibling::b').inner_text.strip.to_i if total_num_records.nil?

      doc.xpath('//table[@id="searchResults"]/tr[position() != 2]').each do |tr|  # skip the second (blank) row
        record_number += 1
        column_number = 0
        record = {}

        # grab each cell and place in an associated record based on the column name
        tr.xpath('td').each do |td|
          column_number += 1  # to get the column name

          # do some mumbo jumbo on the column name to prettyize it
          column_names[column_number] = td.inner_text.strip.downcase.gsub(/[^a-z0-9 ]/, '').gsub(/ /, '_').to_sym if record_number == 1

          record[column_names[column_number]] =
              case column_names[column_number].downcase
                when /date/
                  begin Date.parse(td.inner_text.strip) rescue nil end
                when /amount/
                  td.inner_text.strip.gsub(/[$,]/, '').to_i
                else
                  td.inner_text.strip
              end if record_number > 1  # don't include header in result
        end

        records.push record  if record_number > 1  # don't include header in result
      end

      return records
    end

    # given a mechanized page, extract the overview (list) records in an array of associative records from the profile page
    def extract_overview_from_profile(page)
      html = page.body
      doc = Nokogiri::HTML(html)

      record = Hash.new
      record[:parcel_id] = doc.xpath('//tr[@class="DataletHeaderTop"]/td[@class="DataletHeaderTop"]').first.inner_text.strip.sub(/^PARID: /, '')
      record[:owner_name] = doc.xpath('//tr[@class="DataletHeaderBottom"]/td[1]').first.inner_text.strip
      record[:property_address] = doc.xpath('//tr[@class="DataletHeaderBottom"]/td[2]').first.inner_text.strip
      record[:sales_date] = begin Date.parse(doc.xpath('//table[@id="Last Sale"]/tr[1]/td[2]').first.inner_text.strip) rescue nil end
      record[:sales_amount] = doc.xpath('//table[@id="Last Sale"]/tr[2]/td[2]').first.inner_text.strip.gsub(/[$,]/, '').to_i
      record[:luc] = doc.xpath('//table[@id="Parcel"]/tr[3]/td[2]').first.inner_text.strip
      record[:altid] = doc.xpath('//table[@id="Parcel"]/tr[1]/td[2]').first.inner_text.strip

      return [record]
    end

    # given a mechanized page, extract the overview (list) records in an array of associative records from the profile page
    def extract_from_profile(page)
      html = page.body
      doc = Nokogiri::HTML(html)

      record = Hash.new
      record[:parcel_id] = doc.xpath('//tr[@class="DataletHeaderTop"]/td[@class="DataletHeaderTop"]').first.inner_text.strip.sub(/^PARID: /, '')
      record[:owner_name] = doc.xpath('//tr[@class="DataletHeaderBottom"]/td[1]').first.inner_text.strip
      record[:address] = doc.xpath('//tr[@class="DataletHeaderBottom"]/td[2]').first.inner_text.strip
      record[:sold_date] = begin Date.parse(doc.xpath('//table[@id="Last Sale"]/tr[1]/td[2]').first.inner_text.strip) rescue nil end
      record[:sold_amount] = doc.xpath('//table[@id="Last Sale"]/tr[2]/td[2]').first.inner_text.strip.gsub(/[$,]/, '').to_i

      record[:alt_id] = doc.xpath('//table[@id="Parcel"]/tr[1]/td[2]').first.inner_text.strip
      record[:land_use_code] = begin doc.xpath('//table[@id="Parcel"]/tr[7]/td[2]').first.inner_text.strip.gsub(/[^0-9]/, '').to_i rescue 0 end
      record[:land_use_description] = doc.xpath('//table[@id="Parcel"]/tr[4]/td[2]').first.inner_text.strip
      record[:lot_number] = doc.xpath('//table[@id="Parcel"]/tr[6]/td[2]').first.inner_text.strip
      record[:lot_size] = begin doc.xpath('//table[@id="Parcel"]/tr[7]/td[2]').first.inner_text.strip.gsub(/[^0-9]/, '').to_i rescue 0 end
      record[:front_feet] = begin doc.xpath('//table[@id="Parcel"]/tr[8]/td[2]').first.inner_text.strip.gsub(/[^0-9]/, '').to_i rescue 0 end
      record[:municipality] = doc.xpath('//table[@id="Parcel"]/tr[9]/td[2]').first.inner_text.strip
      record[:school_district] = doc.xpath('//table[@id="Parcel"]/tr[10]/td[2]').first.inner_text.strip
      record[:utilities] = doc.xpath('//table[@id="Parcel"]/tr[11]/td[2]').first.inner_text.strip

      record[:owner_name2] = doc.xpath('//table[@id="Owner"]/tr[2]/td[2]').first.inner_text.strip
      record[:mailing_address] = doc.xpath('//table[@id="Owner"]/tr[3]/td[2]').first.inner_text.strip
      record[:mailing_care_of] = doc.xpath('//table[@id="Owner"]/tr[4]/td[2]').first.inner_text.strip
      record[:mailing_address2] = doc.xpath('//table[@id="Owner"]/tr[5]/td[2]').first.inner_text.strip
      record[:mailing_address3] = doc.xpath('//table[@id="Owner"]/tr[6]/td[2]').first.inner_text.strip

      record[:appraised_value] = begin doc.xpath('//table[@id="Current Assessment"]//tr[2]/td[1]').first.inner_text.strip.gsub(/[^0-9]/, '').to_i rescue 0 end
      record[:assessed_value] = begin doc.xpath('//table[@id="Current Assessment"]//tr[2]/td[2]').first.inner_text.strip.gsub(/[^0-9]/, '').to_i rescue 0 end
      record[:restrict_code] = begin doc.xpath('//table[@id="Current Assessment"]//tr[2]/td[3]').first.inner_text.strip.gsub(/[^0-9]/, '').to_i rescue 0 end

      record[:county_tax] = begin doc.xpath('//table[@id="Estimated Taxes"]//tr[1]/td[2]').first.inner_text.strip.gsub(/[^0-9]/, '').to_i rescue 0 end
      record[:municipality_tax] = begin doc.xpath('//table[@id="Estimated Taxes"]//tr[2]/td[2]').first.inner_text.strip.gsub(/[^0-9]/, '').to_i rescue 0 end
      record[:school_district_tax] = begin doc.xpath('//table[@id="Estimated Taxes"]//tr[3]/td[2]').first.inner_text.strip.gsub(/[^0-9]/, '').to_i rescue 0 end
      record[:estimated_taxes] = begin doc.xpath('//table[@id="Estimated Taxes"]//tr[4]/td[2]').first.inner_text.strip.gsub(/[^0-9]/, '').to_i rescue 0 end
      tax_lien = doc.xpath('//table[@id="Estimated Taxes"]//tr[5]/td[2]').first.inner_text.strip.gsub(/[^0-9]/, '')
      if tax_lien.downcase == 'no'
        record[:tax_lien] = 0
      else
        record[:tax_lien] = begin total.to_i rescue 0 end
      end

      record[:tax_stamps] = begin doc.xpath('//table[@id="Last Sale"]//tr[3]/td[2]').first.inner_text.strip.gsub(/[^0-9]/, '').to_i rescue 0 end
      record[:deed_book_and_page] = doc.xpath('//table[@id="Last Sale"]//tr[4]/td[2]').first.inner_text.strip
      record[:grantor] = doc.xpath('//table[@id="Last Sale"]//tr[5]/td[2]').first.inner_text.strip
      record[:grantee] = doc.xpath('//table[@id="Last Sale"]//tr[6]/td[2]').first.inner_text.strip
      record[:date_sale_recorded] = begin Date.parse(doc.xpath('//table[@id="Last Sale"]//tr[7]/td[2]').first.inner_text.strip) rescue nil end

      return [record]
    end

    def extract_assessment_history(page, parcel_id)
      html = page.body
      doc = Nokogiri::HTML(html)
      records = []
      lineno = 0

      # ignore the last empty row on the table ([0..-2])
      doc.xpath('//table[@id="Assessment History"]//tr[position() > 1]')[0..-2].each do |tr|
        record = Hash.new
        lineno += 1

        record[:parcel_id] = parcel_id
        record[:lineno] = lineno
        record[:appraised_value] = extract_number(tr, 'td[1]')
        record[:assessed_value] = extract_number(tr, 'td[2]')
        record[:restrict_code] = extract_string(tr, 'td[3]')
        record[:effective_date] = extract_date(tr, 'td[4]')
        record[:reason] = extract_string(tr, 'td[5]')
        record[:notice_date] = extract_date(tr, 'td[6]')

        records.push record
      end

      return records
    end

    def extract_sales_history(page, parcel_id)
      html = page.body
      doc = Nokogiri::HTML(html)
      records = []
      lineno = 0
      doc.xpath('//table[@id="Sales History"]//tr[position() > 1]').each do |tr|
        record = Hash.new
        lineno += 1

        record[:parcel_id] = parcel_id
        record[:lineno] = lineno
        record[:sale_date] = extract_date(tr, 'td[1]')
        record[:sale_price] = extract_number(tr, 'td[2]')
        record[:tax_stamps] = extract_number(tr, 'td[3]')
        record[:deed_book_and_page] = extract_string(tr, 'td[4]')
        record[:grantor] = extract_string(tr, 'td[5]')
        record[:grantee] = extract_string(tr, 'td[6]')
        record[:date_recorded] = extract_date(tr, 'td[7]')

        records.push record
      end

      return records
    end

    def extract_residential(page, parcel_id)
      html = page.body
      doc = Nokogiri::HTML(html)

      #return [] if doc.xpath('//td/b[text()="-- No Data --"]')
      record = {}

      record[:parcel_id] = parcel_id
      record[:lineno] = 1
      record[:land_use_code] = extract_string(doc, '//table[@id="Residential Card Summary"]//tr[2]/td[2]')
      record[:building_style] = extract_string(doc, '//table[@id="Residential Card Summary"]//tr[3]/td[2]')
      record[:number_of_living_units] = extract_number(doc, '//table[@id="Residential Card Summary"]//tr[4]/td[2]')
      record[:year_built] = extract_number(doc, '//table[@id="Residential Card Summary"]//tr[5]/td[2]')
      record[:year_remodeled] = extract_number(doc, '//table[@id="Residential Card Summary"]//tr[6]/td[2]')
      record[:exterior_wall_material] = extract_string(doc, '//table[@id="Residential Card Summary"]//tr[7]/td[2]')
      record[:number_of_stories] = extract_number(doc, '//table[@id="Residential Card Summary"]//tr[8]/td[2]')
      record[:sq_ft_of_living_area] = extract_number(doc, '//table[@id="Residential Card Summary"]//tr[9]/td[2]')
      record[:total_rooms] = begin extract_string(doc, '//table[@id="Residential Card Summary"]//tr[10]/td[2]').split('/')[0].to_i rescue 0 end
      record[:total_bedrooms] = begin extract_string(doc, '//table[@id="Residential Card Summary"]//tr[10]/td[2]').split('/')[1].to_i rescue 0 end
      record[:total_baths] = begin extract_string(doc, '//table[@id="Residential Card Summary"]//tr[10]/td[2]').split('/')[2].to_i rescue 0 end
      record[:total_half_baths] = begin extract_string(doc, '//table[@id="Residential Card Summary"]//tr[10]/td[2]').split('/')[3].to_i rescue 0 end
      record[:basement] = extract_string(doc, '//table[@id="Residential Card Summary"]//tr[11]/td[2]')
      record[:finished_basement_living_area] = extract_number(doc, '//table[@id="Residential Card Summary"]//tr[12]/td[2]')
      record[:rec_room_area] = extract_number(doc, '//table[@id="Residential Card Summary"]//tr[13]/td[2]')
      record[:unfinished_area] = extract_number(doc, '//table[@id="Residential Card Summary"]//tr[14]/td[2]')
      record[:wood_burning_fireplace] = extract_number(doc, '//table[@id="Residential Card Summary"]//tr[15]/td[2]')
      record[:pre_fab_fireplace] = extract_number(doc, '//table[@id="Residential Card Summary"]//tr[16]/td[2]')
      record[:heating] = extract_string(doc, '//table[@id="Residential Card Summary"]//tr[17]/td[2]')
      record[:system] = extract_string(doc, '//table[@id="Residential Card Summary"]//tr[18]/td[2]')
      record[:fuel_type] = extract_string(doc, '//table[@id="Residential Card Summary"]//tr[19]/td[2]')
      record[:condo_level] = extract_string(doc, '//table[@id="Residential Card Summary"]//tr[20]/td[2]')
      record[:condo_townhouse_type] = extract_string(doc, '//table[@id="Residential Card Summary"]//tr[21]/td[2]')
      record[:attached_garage_area] = extract_number(doc, '//table[@id="Residential Card Summary"]//tr[22]/td[2]')
      record[:basement_garage_number_of_cars] = extract_number(doc, '//table[@id="Residential Card Summary"]//tr[23]/td[2]')

      return [record]
    end
  end
end
