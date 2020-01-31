# Geocoding Addresses with the ArcGIS REST API (Stanford Affiliates Only)

Instructions for how to use R to access the API of the ArcGIS geodocer provided by the Stanford Branner Library. Access to this service is restricted to Stanford University Affiliates with a valid SUNet ID.


## Stanford Library Geocoding Service

Thanks to our fabulous Geospatial Manager [Stace Maples](https://library.stanford.edu/people/maples) who is tirelessly working to make our GIS lives easier we have our own geocoding service at Stanford:

>> https://locator.stanford.edu/arcgis/rest/services/geocode

The service described here covers the __US only__. The good news here are that there are no limits as of how many addresses you can throw at this server. However, **you need to let Stace know if you are intending to run a major job!**

To use this service :

- You need to be on the Stanford network or use [VPN](https://uit.stanford.edu/service/vpn/).
- You need to authenticate with WebAuth.
- You need to get a token from here https://locator.stanford.edu/arcgis/tokens/

        Username: add WIN\ before your SunetID, for example: WIN\cengel
        Client: RequestIP
        HTTP referer: [leave blank]
        IP:	[leave blank]
        Expiration: (you decide)
        Format: HTML

    (The token is tied to the IP address of the machine that requests the service, so if you use a laptop and move to a different network you may have to request a differnet token.)


## Anatomy of geocoding requests

Now let's put together a URL that will determine the location for `380 New York St,  Redlands, CA`.

Here is what we need:

- The request URL
    `https://locator.stanford.edu/arcgis/rest/services/geocode/USA_Composite /GeocodeServer/geocodeAddresses`

- The request parameters, required are `addresses=`, `token=`, and `format=` (for output).

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

    https://locator.stanford.edu/arcgis/rest/services/geocode/USA_Composite/GeocodeServer/geocodeAddresses?addresses=%7B%22records%22%3A%5B%7B%22attributes%22%3A%7B%22OBJECTID%22%3A1%2C%22SingleLine%22%3A%22380+New+York+St.%2C+Redlands%2CCA%22%7D%7D%5D%7D&&token=<YOUR TOKEN>&f=pjson

The ArcGIS REST geocoding service v10.0 and later takes addresses in [Single Line (also called single field) and Multi Line (also called multi field) mode](http://support.esri.com/technical-article/000011000). That means that the addresses in your table can be stored in a single field (as used in the URL above) or in multiple, separate fields, one for each address component (Street, City, etc). 

Furthermore, there are two ways to send the addresses to the geocoding service: individually or as batch of several. Individual requests are more time consuming. For example, geocoding 1000 addresses takes over 2 minutes as single requests vs. 15 seconds as batch request. Batch geocoding is slightly faster when the address components are stored in separate fields (Multi Line). However, if there is an error in your batch, all the addresses in that batch that already have been geocoded will be dropped. **The maximum number of addresses that can be geocoded in a single batch request on the Stanford geocode server is 1000**.

Lastly, there are two different geocoding services available for the US on Stanford's geolocator: _USA_Composite_ and _USA_StreetAddress_. I have found that for Single Line mode USA Composite provides (supposedly more exact) "PointAddress" results and USA StreetAddress returns (expectedly) "StreetAddress" results, while in Multiline (Batch) mode USA Composite returns "Locality", but USA StreetAddress provides (also expectedly, but possibly more exact) "StreetAddress" results.

## R geocode functions

Here I provide two very simple, **by no means foolproof** R functions to do this. 

First load the functions.

    # source the R code
    source("https://raw.githubusercontent.com/cengel/ArcGIS_geocoding/master/SUL_gcFunctions.R")


### Single Line

`geocodeSL` takes one address at a time in Singleline format. Each address-string is sent as a single request to the geocode server.

**Arguments:**

address - one address at a time as one string (SingleLine)  
token - token  
geocoder - which geocoding service to use: USA_Comp (USA Composite) or USA_Str (USA StreetAddress), default is USA_Comp  
postal - allow to return Postal codes if a full street address match cannot be found, default is TRUE  

**The function returns:**

lon, lat -    The primary x/y coordinates of the address returned by the geocoding service in WGS84  
score -       The accuracy of the address match between 0 and 100.  
status -      Whether a batch geocode request results in a match (M), tie (T), or unmatch (U)  
matchAddr -   Complete address returned for the geocode request.  
side -        The side of the street where an address resides relative to the direction 
               of feature digitization  
addressType - The match level for a geocode request. "PointAddress" is typically the 
               most spatially accurate match level. "StreetAddress" differs from PointAddress 
               because the house number is interpolated from a range of numbers. "StreetName" is similar,
               but without the house number.   

To use it do this.

```R
# make up some addresses:
adr <- c('450 Serra Mall, Stanford, CA, 94305',
         '1600 Amphitheatre Pkwy, Mountain View, CA 94043',
         '1355 Market Street Suite 900, San Francisco, CA 94103')

# set your token
myToken <- "YOUR TOKEN HERE"

# geocode with US Composite
do.call("rbind", lapply(adr, function(x) geocodeSL(x, myToken)))

# geocode with US Street Address
do.call("rbind", lapply(adr, function(x) geocodeSL(x, myToken, geocoder = "USA_Str")))
```

### Multi Line Batch

`geocodeML_batch` takes the address in separate fields and sends them all at once in a POST request.

**Arguments:**

id - ID variable to identify records, must be numeric and should be unique
street, city, state, zip - multiple addresses as vectors, separated into: Street, City, State, Zip,. It can take a maximum of 1000 adresses. If more, it returns an error.  
token - token  
geocoder - which geocoding service to use: USA_Comp (USA Composite) or USA_Str (USA StreetAddress), default is USA_Comp  


**The function returns** 

A data frame with the following fields:

ID -          Result ID can be used to join the output fields in the response to the attributes 
               in the original address table.  
lon, lat -    The primary x/y coordinates of the address returned by the geocoding service in WGS84  
score -       The accuracy of the address match between 0 and 100.  
status -      Whether a batch geocode request results in a match (M), tie (T), or unmatch (U)  
matchAddr -   Complete address returned for the geocode request.  
side -        The side of the street where an address resides relative to the direction 
               of feature digitization  
addressType - The match level for a geocode request. "PointAddress" is typically the 
               most spatially accurate match level. "StreetAddress" differs from PointAddress 
               because the house number is interpolated from a range of numbers. "StreetName" is similar,
               but without the house number.  


To use it do this.

``` R
# make up a data frame with some addresses:
adr_df <- data.frame(
  ID = 1:3,
  street = c('450 Serra Mall', '1600 Amphitheatre Pkwy', '1355 Market Street Suite 900'), 
  city = c('Stanford', 'Mountain View', 'San Francisco'), 
  state = 'CA', 
  zip = c('94305', '94043', '94103'))

# set your token
myToken <- "YOUR TOKEN HERE"
    
# geocode with US Composite
adr_gc_comp <- geocodeML_batch(adr_df$ID, adr_df$street, adr_df$city, adr_df$state, adr_df$zip, myToken)
# join back with original data
merge(adr_df, adr_gc_comp, by = "ID", all.x = T)

# geocode with US Street Address
adr_gc_street <- geocodeML_batch(adr_df$ID, adr_df$street, adr_df$city, adr_df$state, adr_df$zip, myToken, geocoder = "USA_Str")
# join back with original data
merge(adr_df, adr_gc_street, by = "ID", all.x = T)
```

## References

I found [this](https://developers.arcgis.com/rest/geocode/api-reference/geocoding-geocode-addresses.htm) helpful. Even though it is about ESRI's World Geocoder it is very applicable for other ESRI geocoders.
