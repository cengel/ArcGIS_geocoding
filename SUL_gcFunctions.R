################################################
## Single Line, Single Field Geocode Function ##
################################################
# The function takes:
# - one address at a time (Single Line) as one string (Single Field)
# - token
# - allow to return Postal codes if a full street address match cannot be found (default is TRUE)
# The function returns:
# lon, lat -    The primary x/y coordinates of the address returned by the geocoding service in WGS84 
# score -       The accuracy of the address match between 0 and 100.
# locName -     The component locator used to return a particular match result
# status -      Whether a batch geocode request results in a match (M), tie (T), or unmatch (U)
# matchAddr -   Complete address returned for the geocode request.
# side -        The side of the street where an address resides relative to the direction 
#               of feature digitization
# addressType - The match level for a geocode request. "PointAddress" is typically the 
#               most spatially accurate match level. "StreetAddress" differs from PointAddress 
#               because the house number is interpolated from a range of numbers. "StreetName" is similar,
#               but without the house number.

geocodeSLSF <- function (address, token, postal = TRUE){
  require(httr)
  
  # Stanford geolocator
  gserver <- "http://locator.stanford.edu/arcgis/rest/services/geocode/Composite_NorthAmerica/GeocodeServer/geocodeAddresses"

  # template for SingleLine format
  pref <- "{'records':[{'attributes':{'OBJECTID':1,'SingleLine':'"
  suff <- "'}}]}"
  
  # url
  url <- URLencode(paste0(gserver, "?addresses=", pref, address, suff, "&token=", token, ifelse(postal, "&f=json", "&f=json&category=Address")))

  # submit
  rawdata <- GET(url)

  # parse JSON and process result
  res <- content(rawdata, "parsed", "application/json")
  resdf <- with(res$locations[[1]], {data.frame(lon = location$x,
                                                lat = location$y,
                                                score = score, 
                                                locName = attributes$Loc_name,
                                                status = attributes$Status,
                                                matchAddr = attributes$Match_addr,
                                                side = attributes$Side,
                                                addressType = attributes$Addr_type)})
  return(resdf)
}
