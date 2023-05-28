# Geocoding Addresses with the ArcGIS REST API (Stanford Affiliates Only)

Instructions for how to use R to access the API of the ArcGIS geodocer provided by the Stanford Branner Library. **Access to this service is restricted to Stanford University Affiliates with a valid SUNet ID.**


## Stanford Library Geocoding Service

Thanks to our fabulous Director of the Geospatial Center [Stace Maples](https://library.stanford.edu/people/maples) who is tirelessly working to make our GIS lives easier we have our own geocoding service at Stanford:

>> https://locator.stanford.edu/

Geocoder services are currently available for the following regions:
- Asia and Pacific 
- Europe 
- Latin America 
- Middle East and Africa 
- North America 
- USA 

There are no limits as of how many addresses you can throw at this server. However, **you need to let Stace know if you are intending to run a major job!**

To use this service you need to be on the Stanford secure network or use [VPN](https://uit.stanford.edu/service/vpn/).


## Anatomy of geocoding requests

Now let's put together a URL that will determine the location for `380 New York St,  Redlands, CA`.

Here is what we need:

- The request URL
    `https://locator.stanford.edu/arcgis/rest/services/geocode/NorthAmerica/GeocodeServer/geocodeAddresses`

- The request parameters, required are `addresses=` and `format=` (for output).

ArcGIS requires also the input addresses also to be in JSON format, which means they need to look like this:

    addresses=
    {
      "records": [
        {
          "attributes": {
            "OBJECTID": 1,
            "SingleLine": "380 New York St., Redlands, CA, 92373"
          }
        }
      ]
    }


The addresses then need to be [URL encoded](https://en.wikipedia.org/wiki/Percent-encoding). Finally we attach all the request parameters to the geocoding service URL after a `?`

That makes for the following, rather cryptic looking URL:

    https://locator.stanford.edu/arcgis/rest/services/geocode/NorthAmerica/GeocodeServer/geocodeAddresses?addresses=%7B%22records%22%3A%5B%7B%22attributes%22%3A%7B%22OBJECTID%22%3A1%2C%22SingleLine%22%3A%22380+New+York+St.%2C+Redlands%2CCA%22%7D%7D%5D%7D&f=pjson

The ArcGIS REST geocoding service v10.0 and later takes addresses in [Single Line (also called single field) and Multi Line (also called multi field) mode](http://support.esri.com/technical-article/000011000). That means that the addresses in your table can be stored either in a single field (as used in the URL above) or in multiple, separate fields, one for each address component (Street, City, etc). 

Furthermore, there are two ways to send the addresses to the geocoding service: individually or as batch of multiple. Individual requests are more time consuming. Batch geocoding is slightly faster when the address components are stored in separate fields (Multi Line). However, if there is an error in your batch, all the addresses in that batch that already have been geocoded will be dropped. **The maximum number of addresses that can be geocoded in a single batch request on the Stanford geocode server is 1000**.


## R geocode functions

Here I provide two very simple, **by no means foolproof** R functions to do this. 

First load the functions.

    # source the R code
    source("https://raw.githubusercontent.com/cengel/ArcGIS_geocoding/master/SUL_gcFunctions.R")


### Single Line

`geocodeSL` takes one address at a time in Singleline format. Each address-string is sent as a single request to the geocode server.

**Arguments:**

address - one address at a time as one string (SingleLine)  
geocoder - which geocoding service to use. Needs to be one of the following: AsiaPacific, Europe, LatinAmerica, MiddleEastAfrica, NorthAmerica, USA (default is USA) 

**The function returns:**

lon, lat -    The primary x/y coordinates of the address returned by the geocoding service in WGS84  
score -       The accuracy of the address match between 0 and 100.  
status -      Whether a batch geocode request results in a match (M), tie (T), or unmatch (U)  
matchAddr -   Complete address returned for the geocode request.  
addressType - The match level for a geocode request. "PointAddress" is typically the 
               most spatially accurate match level. "StreetAddress" differs from PointAddress 
               because the house number is interpolated from a range of numbers. "StreetName" is similar,
               but without the house number.   

To use it do this.

```R
# make up some addresses:
adr <- c('450 Jane Stanford Way, Stanford, CA, 94305',
         '1600 Amphitheatre Pkwy, Mountain View, CA 94043',
         '1355 Market Street Suite 900, San Francisco, CA 94103')
         
# geocode with USA
do.call("rbind", lapply(adr, function(x) geocodeSL(x)))

# geocode with North America
do.call("rbind", lapply(adr, function(x) geocodeSL(x, geocoder = "NorthAmerica")))

# Europe
geocodeSL("Karl-Marx-Allee 72, 10243, Berlin", geocoder = "Europe")

# Latin America
geocodeSL("Bouchard 547, C1106, Buenos Aires", geocoder = "LatinAmerica")

# Middle East and Africa 
geocodeSL("75 Wale St, 8001, Cape Town", geocoder = "MiddleEastAfrica")

# Asia
geocodeSL("12 Dr. A.P.J. Abdul Kalam Road, New Delhi, 110011", geocoder = "AsiaPacific")

```

### Multi Line Batch

`geocodeML_batch` takes the address in separate fields and sends them all at once in a POST request.

**Arguments:**

id - ID variable to identify records, must be numeric and should be unique
street, city, state, zip - multiple addresses as vectors, separated into: Street, City, State, Zip,. It can take a maximum of 1000 adresses. If more, it returns an error.  
geocoder - which geocoding service to use. Needs to be one of the following: AsiaPacific, Europe, LatinAmerica, MiddleEastAfrica, NorthAmerica, USA (default is USA)  


**The function returns** 

A data frame with the following fields:

ID -          Result ID can be used to join the output fields in the response to the attributes 
               in the original address table.  
lon, lat -    The primary x/y coordinates of the address returned by the geocoding service in WGS84  
score -       The accuracy of the address match between 0 and 100.  
status -      Whether a batch geocode request results in a match (M), tie (T), or unmatch (U)  
matchAddr -   Complete address returned for the geocode request.  
addressType - The match level for a geocode request. "PointAddress" is typically the 
               most spatially accurate match level. "StreetAddress" differs from PointAddress 
               because the house number is interpolated from a range of numbers. "StreetName" is similar,
               but without the house number.  


To use it do this. (To geocode non-US addresses, set state = the respective country.)

``` R
# make up a data frame with some addresses:
adr_df <- data.frame(
  ID = 1:3,
  street = c('450 Jane Stanford Way', '1600 Amphitheatre Pkwy', '1355 Market Street Suite 900'), 
  city = c('Stanford', 'Mountain View', 'San Francisco'), 
  state = 'CA', 
  zip = c('94305', '94043', '94103'))

# geocode with USA
adr_gc_comp <- geocodeML_batch(adr_df$ID, adr_df$street, adr_df$city, adr_df$state, adr_df$zip)
# join back with original data
merge(adr_df, adr_gc_comp, by = "ID", all.x = T)

# geocode with North America
adr_gc_street <- geocodeML_batch(adr_df$ID, adr_df$street, adr_df$city, adr_df$state, adr_df$zip, geocoder = "NorthAmerica")
# join back with address data
merge(adr_df, adr_gc_street, by = "ID", all.x = T)

# geocode with Latin America
adr_df <- data.frame(
  ID = 1,
  street = c('Bouchard 547'), 
  city = c('Buenos Aires'), 
  state = c('Argentina'), 
  zip = c('C1106'))
geocodeML_batch(adr_df$ID, adr_df$street, adr_df$city, adr_df$state, adr_df$zip, geocoder="LatinAmerica")
```

If you have more than 1000 addresses, here is a snippet that sends your addresses in batches of 1000.

``` R
# assumes your addresses are in adr_df

# empty data frame for results
adr_gc_street <- data.frame(ID = integer(0),  lon = numeric(0), lat = numeric(0),
                            score = numeric(0), status = character(), matchAddr= character(0),
                            addressType = character(0))

# geocode loop, using USA geocoder
for(j in 1:ceiling(nrow(adr_df)/1000)) {
  i1 <- 1000*(j-1)+1  # begin of batch
  i2 <- min(1000*j, nrow(adr_df)) # end of batch
  # message
  print(paste("working on rows ",  i1, " to ", i2))
  # geocode batch
  batch <- geocodeML_batch(adr_df$ID[i1:i2], adr_df$street[i1:i2], adr_df$city[i1:i2], adr_df$state[i1:i2], adr_df$zip[i1:i2])
  # add batch to data frame
  adr_gc_street <- rbind(adr_gc_street, batch)
}

# Merge back to addresses
merge(adr_df, adr_gc_street, by = "ID", all.x = T)
```


## References

I found [this](https://developers.arcgis.com/rest/geocode/api-reference/geocoding-geocode-addresses.htm) helpful. Even though it is about ESRI's World Geocoder it is very applicable for other ESRI geocoders.
