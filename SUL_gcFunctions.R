##################################
## Single Line Geocode Function ##
##################################
# The function takes:
# - one address at a time as one string (SingleLine)
# - which geocoding service to use: AsiaPacific, Europe, LatinAmerica, MiddleEastAfrica, NorthAmerica, USA (default is USA)
#
# The function returns:
# lon, lat -    The primary x/y coordinates of the address returned by the geocoding service in WGS84 
# score -       The accuracy of the address match between 0 and 100.
# status -      Whether a batch geocode request results in a match (M), tie (T), or unmatch (U)
# matchAddr -   Complete address returned for the geocode request.
# addressType - The match level for a geocode request. "PointAddress" is typically the 
#               most spatially accurate match level. "StreetAddress" differs from PointAddress 
#               because the house number is interpolated from a range of numbers. "StreetName" is similar,
#               but without the house number.

geocodeSL <- function (address, geocoder = "USA"){
  require(httr)
  
  # geocoders
  if (!geocoder %in% c("AsiaPacific", "Europe", "LatinAmerica", "MiddleEastAfrica", "NorthAmerica","USA")){
    stop("please provide a valid geocoder")
  }
  
  gserver <- paste0("https://locator.stanford.edu/arcgis/rest/services/geocode/", geocoder, "/GeocodeServer/geocodeAddresses")
  pref <- URLencode("{'records':[{'attributes':{'OBJECTID':1,'SingleLine':'", reserved = TRUE)
  suff <- URLencode("'}}]}", reserved = TRUE)
  address_enc <- URLencode(address, reserved = TRUE)
  
  url <- paste0(gserver, "?addresses=", pref, address_enc, suff, "&f=json")
  
  # submit
  rawdata <- GET(url)
  stop_for_status(rawdata) # status check
  warn_for_status(rawdata)
  #message_for_status(rawdata)
  
  # parse JSON and process result
  res <- content(rawdata, "parsed", "application/json")
  resdf <- with(res$locations[[1]], {data.frame(lon = as.numeric(location$x),
                                                lat = as.numeric(location$y),
                                                score = score, 
                                                #locName = attributes$Loc_name,
                                                status = attributes$Status,
                                                matchAddr = attributes$Match_addr,
                                                #side = attributes$Side,
                                                addressType = attributes$Addr_type)})
  return(resdf)
}

#######################################
## Multi Line Batch Geocode Function ##
#######################################
# The function takes:
# - ID variable to identify records, must be numeric and should be unique
# - multiple addresses as vectors, separated into: Street, City, State, Zip
# - which geocoding service to use: AsiaPacific, Europe, LatinAmerica, MiddleEastAfrica, NorthAmerica, USA (default is USA)

#
# It can take a maximum of 1000 addresses. If more, it returns an error.
#
# The function returns a data frame with the following fields:
# ID -          Result ID can be used to join the output fields in the response to the attributes 
#               in the original address table.
# lon, lat -    The primary x/y coordinates of the address returned by the geocoding service in WGS84 
# score -       The accuracy of the address match between 0 and 100.
# status -      Whether a batch geocode request results in a match (M), tie (T), or unmatch (U)
# matchAddr -   Complete address returned for the geocode request.
# addressType - The match level for a geocode request. "PointAddress" is typically the 
#               most spatially accurate match level. "StreetAddress" differs from PointAddress 
#               because the house number is interpolated from a range of numbers. "StreetName" is similar,
#               but without the house number.
 
geocodeML_batch <- function(id, street, city, state, zip, geocoder = "USA"){
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
  
  # geocoders
  if (!geocoder %in% c("AsiaPacific", "Europe", "LatinAmerica", "MiddleEastAfrica", "NorthAmerica","USA")){
    stop("please provide a valid geocoder")
  }
  
  gserver <- paste0("https://locator.stanford.edu/arcgis/rest/services/geocode/", geocoder, "/GeocodeServer/geocodeAddresses")
  
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
  adr_json_enc <- URLencode(adr_json, reserved = TRUE)
  
  
  # submit
  req <- POST(
    url = gserver, 
    body = list(addresses = adr_json, f="json"),
    encode = "form")
  stop_for_status(req) # status check
  warn_for_status(req)
  #message_for_status(req)
  
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
                                              #side = attributes$Side,
                                              addressType = attributes$Addr_type)})
    resdfr <- rbind(resdfr, d)
  }

  return(resdfr)
}
