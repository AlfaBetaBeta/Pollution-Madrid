# Study of air pollution in Madrid

This repository showcases an analysis of air quality data, based on air pollutant and environmental variable information available from weather stations distributed across the city of Madrid.

The main processing and exploration pipeline can be inspected in the html document resulting from knitting `Air.Rmd`. Otherwise, its contents are summarised in the following sections:

* [Data sources]()
* [Hourly data integration]()
* [Data processing and assembly]()
* [Descriptive analysis]()
    * [Correlation matrices]()
    * [Distribution of parameters]()
    * [Time series]()
* [Multiple linear regression]()


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

<sup>\*</sup> *For simplicity, and to limit the size of the repository, `hourly_data/` contains here only a sample consisting of the first 24 monthly files. The graphs shown in the [descriptive analytics]() and [regression]() sections, however, refer to the entire six year time span.* 


## Hourly data integration

The first step is to programmatically retrieve all the hourly data. To this end, all `.csv` filenames are stored in a vector (`files_list`, each value a relative path, including the directory file prepended) for use in the working directory:
```
files_list <- list.files(path = "./hourly_data", pattern = ".csv", full.names = TRUE)
```

Note that any given stored filename follows the pattern `hourly_data_YY_m(m).csv`, where `YY` spans between `11` and `16`, and `m/mm` between `1` and `12`. Hence, the next step is to extract the date and file type information as a regex from each filename in `files_list`, drop the extension (`.csv`) and split the year and month, storing them as separate strings for each filename in a new list `tmp_YM`. This can be neatly accomplished as follows:
```
tmp_YM <- strsplit(gsub("\\.csv$","", str_extract(files_list, "[0-9]+_[0-9]+\\.csv")), split = '_')
```

Finally, the following steps can be applied iteratively within a for-loop over the entire sequence of files, generating a single dataframe (`hourly_df`) with the hourly data of the entire time span:

* read cycle file into a dataframe
* apply `cbind()` to attach `year` and `month` columns to the dataframe
    * `year` and `month` values are retrieved from list `tmp_YM` and coerced to integers
    * `year` value is extended from `YY` to `YYYY` format
    * `year` and `month` values are implicitly recycled as necessary to match the number of rows of the dataframe
* apply `rbind()` to append the dataframe to the cumulative dataframe embedding all rows up to the previous cycle
* for the very first cycle, the cumulative dataframe is initialised as an empty dataframe
```
hourly_df <- data.frame()
for (idx in 1:length(files_list)) {
    tmp_df <- cbind(year = as.integer(paste0('20', tmp_YM[[idx]][1])), month = as.integer(tmp_YM[[idx]][2]), read.csv(files_list[idx]))
    hourly_df <- rbind(hourly_df, tmp_df)
}
```
This operation constitutes the computational bottleneck of the entire process and, depending on the machine or runtime settings, it may take up to a few minutes. It is not argued here that this approach is efficient, it is merely functional and leaves plenty of room for improvement. Future revisions of this repository will address this issue, aiming at optimising the assembly.


## Data processing and assembly


## Descriptive analysis

