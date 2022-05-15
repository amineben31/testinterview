

def process_application_created_event(application)
  fund_accounts = FundAccount.all.sort_by(&:criteria_location_matching_priority).reverse

  fund_accounts.each do |fund_account|
    if fund_account.match_location?(application.full_address, application.latlong)
      allocate_funding_to_application(application, fund_account)
      return
    end
  end

  puts "No allocatable fund for this location"
end


class FundAccount
  def location_match
    # Not provided for simplicity, but expect output to be in one of 3 shapes, illustrated in the examples below:

    # Circle type
    # {
    #   'type' => 'circle',
    #   'options' => {
    #     'centre' => [53.270668, -9.0567905],
    #     'radius' => 10000,
    #   }
    # }

    # Polygon type
    # {
    #   'type' => 'polygon',
    #   'options' => {
    #     'centre' => [53.270668, -9.0567905],
    #     'points' => [[53.369669, -6.349048], [53.358093, -6.356429], [53.346720, -6.337976]],
    #   }
    # }

    # Region type
    # {
    #   'type' => 'region',
    #   'options' => {
    #     'centre' => [53.270668, -9.0567905],
    #     'regions' => ['london', 'brighton'],
    #   }
    # }
  end
  def criteria_location_matching_priority
  	#this is a different way to use it just to make it smaller
  	#  location_match['circle'] ? 2 : 
  	#  location_match['region'] ? (location_match.dig('options', 'regions') == ['*']) ? 0 : 1 :
  	#  raise "Matching priority not defined for type '#{location_match['type']}'"
    case location_match['type']
    when 'circle'
      2
    when 'region'
      (location_match.dig('options', 'regions') == ['*']) ? 0 : 1
    else
      raise "Matching priority not defined for type '#{location_match['type']}'"
    end
  end

  def match_location?(region: nil, latlong: nil)
  	#we can directly add location_match to the parameters :  
  	#  if location_match['type']
  	# matches_location_by_region?(location_match, location_match['type'])
    if location_match['type'] == 'region'
      matches_location_by_region?(location_match, region)
    elsif location_match['type'] == 'circle'
      matches_location_by_point?(location_match, latlong)
    elsif location_match['type'] == 'polygon'
      matches_location_by_polygon?(location_match, latlong)
    else
      raise "unexpected location match type: #{location_match}"
    end
  end

  private def matches_location_by_point?(location_match, latlong)
    # use : return !latlong   
    return false if latlong.nil?
    # we don't need to alocate center and radius we can add it directly to GeoService.distance_between(center, latlong) <= radius :
    # GeoService.distance_between(location_match['options']['centre'], latlong) <= location_match['options']['radius']
    # to save memory
    center = location_match['options']['centre']
    radius = location_match['options']['radius']

    GeoService.distance_between(center, latlong) <= radius
  end

  private def matches_location_by_region?(location_match, region)
    # use : return !region && location_match['options']['regions'] == ["*"]  to avoid double returns and save execution time
    return false if region.nil?

    return true if location_match['options']['regions'] == ["*"]
	# region.match(/\b#{[*location_match['options']['regions']].map { |region| Regexp.escape(region) }.join('|')}\b/i)
    location_regions = [*location_match['options']['regions']].map { |region| Regexp.escape(region) }

    region.match(/\b#{location_regions.join('|')}\b/i)
  end

  private def matches_location_by_polygon?(location_match, latlong)
    # use : return !latlong  
    return false if latlong.nil?

    GeoService.point_inside_polygon?(latlong, location_match['options']['points'])
  end
end
