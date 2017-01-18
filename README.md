# Geocoding Addresses with the ArcGIS REST API (Stanford Affiliates Only)

Instructions for how to use R to access the API of the ArcGIS geodocer provided by the Stanford Branner Library. Access to this service is restricted to Stanford University Affiliates with a valid SUNet ID.


## Stanford Library Geocoding Service

Thanks to our fabulous Geospatial Manager [Stace Maples](https://library.stanford.edu/people/maples) who is tirelessly working to make our GIS lives easier we have our own geocoding service at Stanford:

>> http://locator.stanford.edu/arcgis/rest/services/geocode

The services described here covers the US and Canada only ([ArcGIS Composite North America Geocode Service](http://help.arcgis.com/en/data-appliance/4.0/help/basemap/content/na_address_locator_10.htm). The good news here are that there are no limits as of how many addresses you can throw at this server. However, **you need let Stace know if you are intending to run a major job!**

To use this service :

- You need to be on the Stanford network or use [VPN](https://uit.stanford.edu/service/vpn/).
- You need to authenticate with WebAuth.
- You need to get a token from here http://locator.stanford.edu/arcgis/tokens/

        Username: add WIN\ before your SunetID, for example: WIN\cengel
        Client: RequestIP
        HTTP referer: [leave blank]
        IP:	[leave blank]
        Expiration: (you decide)
        Format: HTML

    (The token is tied to the IP address of the machine that requests the service, so if you use a laptop and move, say, from your home wireless over VPN to your lab on campus, the same token will not work.)


## Anatomy of geocoding requests

Now let's put together a URL that will determine the location for `380 New York St,  Redlands, CA`.

Here is what we need:

- The request URL
    `http://locator.stanford.edu/arcgis/rest/services/geocode/Composite_NorthAmerica/GeocodeServer/geocodeAddresses`

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


We attach all the request parameters to the geocoding service URL after a `?`

That makes for the following URL:

    http://locator.stanford.edu/arcgis/rest/services/geocode/Composite_NorthAmerica/GeocodeServer/geocodeAddresses?addresses={"records":[{"attributes":{"OBJECTID":1,"SingleLine":"380 New York St., Redlands, CA"}}]}&token=<YOUR TOKEN>&f=pjson

The ArcGIS REST geocoding service v10.0 and later takes addresses in [SingleLine (also called single field) and MultiLine (also called multi field) mode](http://support.esri.com/technical-article/000011000). That means that the addresses in your table can be stored in a single field (as used above) or in multiple fields, one for each address component (Street, City, etc). The _quality_ of the returned result will not be affected by the form requests are submitted.

Batch geocoding _performance_ is better when the address parts are stored in separate fields. However, if there is an error in your batch, all the addresses in that batch that already have been geocoded will be dropped. Furthermore, a lot of addresses in one batch can cause the URL length limit to be exceeded and the URL to be truncated, so it is necessary to use the POST method to send those requests. The maximum number of addresses that can be geocoded in a single batch request on the Stanford geocode server is set to **1000**.

## R geocode function

Here I provide a very simple, **by no means foolproof** R function to do this, called `geocodeSL`. It takes one address at a time in Singleline format.

To use it do this.

    # make up some addresses:
    adr <- c('450 Serra Mall, Stanford, CA, 94305',
              '1600 Amphitheatre Pkwy, Mountain View, CA 94043',
              '1355 Market Street Suite 900, San Francisco, CA 94103')

    # source the R code
    source("https://raw.githubusercontent.com/cengel/ArcGIS_geocoding/master/SUL_gcFunctions.R")

    # set your token
    myToken <- "YOUR TOKEN HERE"

    # geocode with
    do.call("rbind", lapply(adr, function(x) geocodeSL(x, myToken)))


## References

I found [this](https://developers.arcgis.com/rest/geocode/api-reference/geocoding-geocode-addresses.htm) helpful. Even though it is about ESRI's World Geocoder it is very applicable for other ESRI geocoders.


## To Do
- option to submit multiple field and multiple line addresses
- option to return more (and less) values
- add error checks (check for `#` in address and provide proper feedback)
