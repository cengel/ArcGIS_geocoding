## begin geocode function 
# takes token and one address at a time (Single Line) as single line (Single Field)
# currently returns lat, lon, status, score, side, match address.
geocodeSLSF <- function (address, token){
  require(httr)
  gserver <- "http://locator.stanford.edu/arcgis/rest/services/geocode/Composite_NorthAmerica/GeocodeServer/geocodeAddresses"

  # template for SingleLine format
  pref <- "{'records':[{'attributes':{'OBJECTID':1,'SingleLine':'"
  suff <- "'}}]}"
  url <- URLencode(paste0(gserver, "?addresses=", pref, address, suff, "&token=", token, "&f=json"))

  # submit
  rawdata <- GET(url)

  # parse JSON and process result
  res <- content(rawdata, "parsed", "application/json")
  resdf <- with(res$locations[[1]], {data.frame(lat = attributes$Y,
                                                lon = attributes$X,
                                                status = attributes$Status,
                                                score = attributes$Score,
                                                side = attributes$Side,
                                                matchAdr = attributes$Match_addr)})
  return(resdf)
}
## end geocode function