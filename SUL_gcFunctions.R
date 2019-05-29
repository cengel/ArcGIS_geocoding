##################################
## Single Line Geocode Function ##
##################################
# The function takes:
# - one address at a time as one string (SingleLine)
# - token
# - which geocoding service to use: USA_Comp (USA Composite) or USA_Str (USA StreetAddress) (default is USA_Comp)
# - allow to return Postal codes if a full street address match cannot be found (default is TRUE)
#
# The function returns:
# lon, lat -    The primary x/y coordinates of the address returned by the geocoding service in WGS84 
# score -       The accuracy of the address match between 0 and 100.
# status -      Whether a batch geocode request results in a match (M), tie (T), or unmatch (U)
# matchAddr -   Complete address returned for the geocode request.
# side -        The side of the street where an address resides relative to the direction 
#               of feature digitization
# addressType - The match level for a geocode request. "PointAddress" is typically the 
#               most spatially accurate match level. "StreetAddress" differs from PointAddress 
#               because the house number is interpolated from a range of numbers. "StreetName" is similar,
#               but without the house number.

geocodeSL <- function (address, token, geocoder = "USA_Comp", postal = TRUE){
  require(httr)
  
  if (geocoder == "USA_Str"){
    # Stanford geolocator
    gserver <- "http://locator.stanford.edu/arcgis/rest/services/geocode/USA_StreetAddress/GeocodeServer/geocodeAddresses"
    # template for Single Line format
    pref <- "{'records':[{'attributes':{'OBJECTID':1,'Single Line Input':'"
  }
  else if (geocoder == "USA_Comp") {
    gserver <- "http://locator.stanford.edu/arcgis/rest/services/geocode/USA_Composite/GeocodeServer/geocodeAddresses"
    pref <- "{'records':[{'attributes':{'OBJECTID':1,'SingleLine':'"
  }
  else{
    stop("please provide a valid geocoder")
  }
  
  suff <- "'}}]}"
  
  # url
  url <- URLencode(paste0(gserver, "?addresses=", pref, address, suff, "&token=", token, ifelse(postal, "&f=json", "&f=json&category=Address")))

  # submit
  rawdata <- GET(url)

  # parse JSON and process result
  res <- content(rawdata, "parsed", "application/json")
  resdf <- with(res$locations[[1]], {data.frame(lon = as.numeric(location$x),
                                                lat = as.numeric(location$y),
                                                score = score, 
                                                #locName = attributes$Loc_name,
                                                status = attributes$Status,
                                                matchAddr = attributes$Match_addr,
                                                side = attributes$Side,
                                                addressType = attributes$Addr_type)})
  return(resdf)
}

#######################################
## Multi Line Batch Geocode Function ##
#######################################
# The function takes:
# - ID variable to identify records, must be numeric and should be unique
# - multiple addresses as vectors, separated into: Street, City, State, Zip
# - token
# - which geocoding service to use: USA_Comp (USA Composite) or USA_Str (USA StreetAddress) (default is USA_Comp)

#
# It can take a maximum of 1000 adresses. If more, it returns an error.
#
# The function returns a data frame with the following fields:
# ID -          Result ID can be used to join the output fields in the response to the attributes 
#               in the original address table.
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
 
geocodeML_batch <- function(id, street, city, state, zip, token, geocoder = "USA_Comp"){
  require(httr)
  require(rjson)
  
  # check if we have more than 1000, if so stop.
  if (length(id) > 1000){
    print(paste("length is: ", length(id)))
    stop("Can only process up to 1000 addresses at a time.")}
  
  # check if id is numeric, either a real number or a string number
  if(!all(grepl("^[0-9]{1,}$", id))){ # HT: https://stackoverflow.com/a/48954452/2630957
  #if (!is.numeric(id)) {
    stop("id variable needs to be a number")
  }
  
  # make data frame
  adr_df <- data.frame(OBJECTID = id,  # we need the id to be called OBJECTID
                       Street = street,
                       City = city,
                       State = state,
                       Zip = zip)

  # Set missing ZIP codes to empty strings
  adr_df$Zip <- ifelse(is.na(adr_df$Zip), '', as.character(adr_df$Zip))
  
  # make json
  tmp_list <- apply(adr_df, 1, function(i) list(attributes = as.list(i)))
  # need to coerce OBJECTID to numeric
  tmp_list <- lapply(tmp_list, function(i) { 
    i$attributes$OBJECTID <- as.numeric(i$attributes$OBJECTID); 
    i})

  adr_json <- toJSON(list(records = tmp_list))
  
  if(geocoder == "USA_Comp"){
    gserver <- "http://locator.stanford.edu/arcgis/rest/services/geocode/USA_Composite/GeocodeServer/geocodeAddresses"
    }
  else if(geocoder == "USA_Str"){
    gserver <- "http://locator.stanford.edu/arcgis/rest/services/geocode/USA_StreetAddress/GeocodeServer/geocodeAddresses"
  }
  else{
    stop(paste(geocoder, "please provide a valid geocoder"))
  }
  
  # submit
  req <- POST(
    url = gserver, 
    body = list(addresses = adr_json, f="json", token=token),
    encode = "form")
  #stop_for_status(req) # error check
  
  # process and parse
  res <- content(req, "parsed", "application/json")
  
  resdfr <- data.frame()
  for (i in seq_len(length(res$locations))){
    d <- with(res$locations[[i]], {data.frame(ID = attributes$ResultID,
                                              lon = as.numeric(location$x),
                                              lat = as.numeric(location$y),
                                              score = score, 
                                              #locName = attributes$Loc_name,
                                              status = attributes$Status,
                                              matchAddr = attributes$Match_addr,
                                              side = attributes$Side,
                                              addressType = attributes$Addr_type)})
    resdfr <- rbind(resdfr, d)
  }

  return(resdfr)
}
