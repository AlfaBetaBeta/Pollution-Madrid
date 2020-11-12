# Study of air pollution in Madrid

Analysis of air quality data, based on air pollutant and environmental variable information available from weather stations distributed across the city of Madrid.

The main processing and exploration pipeline can be inspected in the html document resulting from knitting `Air.Rmd`. Otherwise, its contents are summarised in the following sections:

* [Data sources]
* [Data integration and assembly]
* [Data processing]
* [Descriptive analysis]
    * [Correlation matrices]
    * [Distribution of parameters]
    * [Time series]
* [Multiple linear regression]


## Data sources

Raw data is distributed across three distinct directories:

* `hourly_data/`: comprises 72 `.csv` files, each one corresponding to a certain year and month, originally spanning between January 2011 and December 2016<sup>\*</sup>. These files contain hourly information consistently distributed amongst five columns:
    * `day`: day of the month.
    * `hour`: hour of the day (1 to 24).
    * `station`: ID uniquely identifying the weather station.
    * `parameter`: numerically encoded parameters (pollutants) measured by the stations.
    * `value`: value of the relevant pollutant measure.

* `geo_data/`: comprises a single `.xlsx` file with geolocation information per station as per the following four columns:
    * `Station`: ID uniquely identifying the weather station.
    * `long`: longitude.
    * `lat`: latitude.
    * `Retiro`: auxiliary binary column to identify the reference station (located at the city centre) at Retiro Park.

* `weather_data/`: comprises a single `.xlsx` file with daily weather related measurements from the Retiro station:
	* `date`: date of measurements.
	* `temp_avg`: average daily temperature (in Celsius).
	* `temp_max`: maximum daily temperature (in Celsius).
	* `temp_min`: minimum daily temperature (in Celsius).
	* `precipitation`: daily precipitation (in mm).
	* `humidity`: (in %).
	* `wind_avg_speed`: average daily wind speed (in m/sec).
