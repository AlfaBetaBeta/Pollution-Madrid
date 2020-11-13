# Study of air pollution in Madrid

This repository showcases an analysis of air quality data, based on air pollutant and environmental variable information available from weather stations distributed across the city of Madrid.

The main processing and exploration pipeline can be inspected in the html document resulting from knitting `Air.Rmd`. Otherwise, its contents are summarised in the following sections:

* [Data sources]()
* [Hourly data integration]()
* [Data processing and final assembly]()
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

For reference, inspection of `hourly_df` at this point renders (only first six rows for clarity):

| year | month | day | hour |  station | parameter | value |
| :--: | :---: | :-: | :--: | :------: | :-------: | :---: |
| 2011 |   1   |  1  |   1  | 28079004 |     1     |   6   |
| 2011 |   1   |  1  |   1  | 28079008 |     1     |  12   |
| 2011 |   1   |  1  |   1  | 28079017 |     1     |  12   |
| 2011 |   1   |  1  |   1  | 28079018 |     1     |  10   |
| 2011 |   1   |  1  |   1  | 28079024 |     1     |   7   |
| 2011 |   1   |  1  |   1  | 28079035 |     1     |  11   |


## Data processing and final assembly

### Parameter data

Several parameters are measured in the weather stations, but in the context of this study only four of them are of interest. In `hourly_df`, they are encoded as follows:

* `8` = NO<sub>2</sub>
* `1` = SO<sub>2</sub>
* `14` = O<sub>3</sub>
* `9` = PMO<sub>2.5</sub>

These equivalences can be stored in an auxiliary dataframe, using it to subset `parameter` rows from `hourly_df`, and dropping the rest:
```
df_eq <- data.frame(code = c(8,1,14,9), pollutant = c('NO2','SO2','O3','PM2.5'))
parameters <- as.integer(df_eq$code)
hourly_df <- subset(hourly_df, subset = parameter %in% parameters)
```

At this point, it is possible to aggregate `hourly_df` to day level by:

1. averaging the value of each parameter over all stations for each hourly timestamp
2. average all (averaged) hourly values within the same daily timestamp for each parameter
```
hourly_df <- aggregate(hourly_df$value,
                       by = list(parameter = hourly_df$parameter,
                                 hour = hourly_df$hour,
                                 day = hourly_df$day,
                                 month = hourly_df$month,
                                 year = hourly_df$year),
                       FUN = mean, na.rm = T)
names(hourly_df)[names(hourly_df) == 'x'] <- 'value'

hourly_df <- aggregate(hourly_df$value,
                       by = list(parameter = hourly_df$parameter,
                                 day = hourly_df$day,
                                 month = hourly_df$month,
                                 year = hourly_df$year),
                       FUN = mean)
names(hourly_df)[names(hourly_df) == 'x'] <- 'value'
```

Casting the column `parameter` from **integer** to **factor** allows for showing the names of the pollutants as levels:
```
hourly_df$parameter <- factor(hourly_df$parameter, levels = df_eq$code, labels = df_eq$pollutant)
```

Lastly, pasting `year`, `month` and `day` columns into a single `YYYY-MM-DD` character type column (with implicit coertion from **integer** to **character**), casting `date` from **character** to **Date** type column, and removing the original `year`, `month` and `day` columns, leaves `hourly_df` in the state needed for subsequent steps.
```
hourly_df$date <- paste(hourly_df$year, hourly_df$month, hourly_df$day, sep = "-")
hourly_df$date <- as.Date(hourly_df$date, format = "%Y-%m-%d")
hourly_df[,c('year','month','day')] <- NULL
```

For reference, inspection of `hourly_df` at this point renders (only first six rows for clarity):

| parameter |    value     |    date    |
| :-------: | :----------: | :--------: |
|    SO2    |  10.712500   | 2011-01-01 |
|    NO2    |  41.510417   | 2011-01-01 |
|   PM2.5   |   9.416667   | 2011-01-01 |
|    O3     |  20.473214   | 2011-01-01 |
|    SO2    |  11.933333   | 2011-01-02 |
|    NO2    |  48.473958   | 2011-01-02 |


### Weather data

Shifting focus to the `weather_data/` directory, and reading the `.xlsx` file into a dataframe, the following steps are executed:

 * Keep only columns `date`, `temp_avg`, `precipitation` and `wind_avg_speed`
 * Cast `date` column from **DateTime** to **Date**
 * Merge `hourly_df` and `weather_df` via inner join by `date` (both columns are in `YYYY-MM-DD` format)
```
weather_df <- read_excel("./weather_data/weather.xlsx")

weather_df <- subset(weather_df, select = c(date, temp_avg, precipitation, wind_avg_speed))
weather_df$date <- as.Date(weather_df$date, format = "%Y-%m-%d")

df <- merge(hourly_df, weather_df, by = 'date')
```

As a minor feature engineering step, let us add a factor column to distinguish season within the year:
```
df$season <- factor(ifelse(3 <= month(df$date) & month(df$date) <= 5, 'Spring',
                           ifelse(6 <= month(df$date) & month(df$date) <= 8, 'Summer',
                                  ifelse(9 <= month(df$date) & month(df$date) <= 11, 'Autumn', 'Winter'))),
                    levels = c('Spring','Summer','Autumn','Winter'))
```

Inspection of `df` at this point renders (only first six rows for clarity):

|    date    | parameter |    value     | temp_avg | precipitation | wind_avg_speed | season |
| :--------: | :-------: | :----------: | :------: | :-----------: | :------------: | :----: |
| 2011-01-01 |    SO2    |  10.712500   |   8.3    |       0       |       5.2      | Winter |
| 2011-01-01 |    NO2    |  41.510417   |   8.3    |       0       |       5.2      | Winter |
| 2011-01-01 |   PM2.5   |   9.416667   |   8.3    |       0       |       5.2      | Winter |
| 2011-01-01 |    O3     |  20.473214   |   8.3    |       0       |       5.2      | Winter |
| 2011-01-02 |    SO2    |  11.933333   |   8.6    |       0       |       5.4      | Winter |
| 2011-01-02 |    NO2    |  48.473958   |   8.6    |       0       |       5.4      | Winter |

For ease of `ggplot` executions in the [descriptive analysis]() section, store alternative shapes of `df` via `melt()` and `dcast()`:

* Shorten `df` length and expand `df` width by having `parameter` values in separate columns
* Extend `df` length and contract `df` width by having `weather` variables as factor levels in a common column

Execution and inspection is shown below for reference:
```
dt_wide <- dcast(as.data.table(df),
                 date + season + temp_avg + precipitation + wind_avg_speed ~ parameter,
                 value.var = 'value')
```

| &nbsp;&nbsp;date&nbsp;&nbsp;    | season | temp_avg | precipitation | wind_avg_speed |    NO2   |    SO2    |     O3    |   PM2.5   |
| :-----------------------------: | :----: | :------: | :-----------: | :------------: | :------: | :-------: | :-------: | :-------: |
| 2011-01-01                      | Winter |   8.3    |     0.00      |       5.2      | 41.51042 | 10.712500 | 20.473214 |  9.416667 |
| 2011-01-02                      | Winter |   8.6    |     0.00      |       5.4      | 48.47396 | 11.933333 | 15.562500 |  9.076389 |
| 2011-01-03                      | Winter |   4.2    |     0.00      |       3.5      | 63.63368 | 11.906019 |  9.446429 | 11.944444 |
| 2011-01-04                      | Winter |   6.5    |     0.00      |       6.3      | 46.29514 |  8.841667 | 13.342262 |  9.402778 |
| 2011-01-05                      | Winter |   8.9    |     0.00      |      10.4      | 51.51736 |  9.505093 | 10.883929 | 10.513889 |
| 2011-01-06                      | Winter |  12.2    |     0.51      |      15.7      | 35.32812 |  8.633333 | 23.419643 |  6.979167 |

```
dt_long <- melt(as.data.table(df),
                id.vars = c('date', 'season', 'parameter','value'),
                measure.vars = c('temp_avg','precipitation','wind_avg_speed'),
                variable.name = 'weather_variable',
                value.name = 'weather_value')
```

|    date    | season | parameter |    value     | weather_variable | weather_value |
| :--------: | :----: | :-------: | :----------: | :--------------: | :-----------: |
| 2011-01-01 | Winter |    SO2    |  10.712500   |     temp_avg     |      8.3      |
| 2011-01-01 | Winter |    NO2    |  41.510417   |     temp_avg     |      8.3      |
| 2011-01-01 | Winter |   PM2.5   |   9.416667   |     temp_avg     |      8.3      |
| 2011-01-01 | Winter |    O3     |  20.473214   |     temp_avg     |      8.3      |
| 2011-01-02 | Winter |    SO2    |  11.933333   |     temp_avg     |      8.6      |
| 2011-01-02 | Winter |    NO2    |  48.473958   |     temp_avg     |      8.6      |


## Descriptive analysis

Under construction...