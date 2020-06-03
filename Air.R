#### 1.READ EVERY PIECE OF RAW DATA AND INTEGRATE ALL IN A NEW HOURLY DATASET ####

# Store all .csv files in a vector, including the directory file prepended for use in the working directory:
files_list <- list.files(path = "./workgroup_data", pattern = ".csv", full.names = TRUE)

# Load library stringr, installing it beforehand if necessary, for use in the subsequent step:
if (!'stringr' %in% installed.packages()) {
    install.packages('stringr')
} 
library(stringr)

# From the list of file names:
# - extract the date and file type information <YY>_<M/MM>.csv as a regex from each file name
# - drop the extension .csv
# - split the year and month and store as separate strings for each file name
tmp_YM <- strsplit(gsub("\\.csv$","", str_extract(files_list, "[0-9]+_[0-9]+\\.csv")),
                   split = '_')

# Within a for-loop over the entire sequence of files:
# - read file into a dataframe
# - apply cbind() to attach 'year' and 'month' columns to the dataframe
#       + 'year' and 'month' values are retrieved from list tmp_YM and coerced to integers
#       + 'year' value is extended from YY to YYYY format
#       + 'year' and 'month' values are implicitly recycled as necessary to match the number of rows of the dataframe
# - apply rbind() to append the dataframe to the cumulative dataframe embedding all rows up to the previous cycle
#       + for the very first cycle, the cumulative dataframe is initialised as an empty dataframe
hourly_df <- data.frame()
for (idx in 1:length(files_list)) {
    tmp_df <- cbind(year = as.integer(paste0('20', tmp_YM[[idx]][1])),
                    month = as.integer(tmp_YM[[idx]][2]),
                    read.csv(files_list[idx]))
    hourly_df <- rbind(hourly_df, tmp_df)
}
# Remove the temporary dataframe from the last cycle:
rm(tmp_df)


#### 2.PROCESS THE HOURLY DATA TO CREATE A DAILY DATASET, BY AVERAGING EACH HOURLY MEASURE,  ####
####   CONTAINING ALSO THE WEATHER VARIABLES AND THE NAMES FOR EACH POLLUTANT PARAMETER      ####

# The parameters of interest in hourly_df are:
# NO2 = 8   ;   SO2 = 1 ;   O3 = 14 ;   PM2.5 = 9
# Store these equivalences in an auxiliary dataframe
df_eq <- data.frame(code = c(8,1,14,9), pollutant = c('NO2','SO2','O3','PM2.5'))
parameters <- as.integer(df_eq$code)
# Subset parameter rows from hourly_df and drop the rest:
hourly_df <- subset(hourly_df, subset = parameter %in% parameters)

# Aggregate hourly_df by:
# (1) averaging the value of each parameter over all stations for each hourly timestamp
hourly_df <- aggregate(hourly_df$value,
                       by = list(parameter = hourly_df$parameter,
                                 hour = hourly_df$hour,
                                 day = hourly_df$day,
                                 month = hourly_df$month,
                                 year = hourly_df$year),
                       FUN = mean, na.rm = T)
names(hourly_df)[names(hourly_df) == 'x'] <- 'value' # rename aggregated column back to 'value'

# (2) average all (averaged) hourly values within the same daily timestamp for each parameter
hourly_df <- aggregate(hourly_df$value,
                       by = list(parameter = hourly_df$parameter,
                                 day = hourly_df$day,
                                 month = hourly_df$month,
                                 year = hourly_df$year),
                       FUN = mean)
names(hourly_df)[names(hourly_df) == 'x'] <- 'value' # rename aggregated column back to 'value'

# Change column 'parameter' from integer to factor, showing the names of the pollutants as levels:
hourly_df$parameter <- factor(hourly_df$parameter, levels = df_eq$code, labels = df_eq$pollutant)

# Paste 'year', 'month' and 'day' columns into a single YYYY-MM-DD character type column
# (with implicit coertion from int to string):
hourly_df$date <- paste(hourly_df$year, hourly_df$month, hourly_df$day, sep = "-")
# Transform 'date' from character to date type column:
hourly_df$date <- as.Date(hourly_df$date, format = "%Y-%m-%d")
# Remove original 'year', 'month' and 'day' columns:
hourly_df[,c('year','month','day')] <- NULL

# Load library readxl, installing it beforehand if necessary, for use in the subsequent step:
if (!'readxl' %in% installed.packages()) {
    install.packages('readxl')
} 
library(readxl)

# Read .xlsx file into a dataframe:
weather_df <- read_excel("./weather.xlsx")

# Keep only columns 'date', 'temp_avg', 'precipitation' and 'wind_avg_speed'
weather_df <- subset(weather_df, select = c(date, temp_avg, precipitation, wind_avg_speed))

# Transform 'date' column from datetime to date:
weather_df$date <- as.Date(weather_df$date, format = "%Y-%m-%d")

# Merge hourly_df and weather_df via inner join by 'date' (both columns are in YYYY-MM-DD format):
df <- merge(hourly_df, weather_df, by = 'date')

if (!'lubridate' %in% installed.packages()) {
    install.packages('lubridate')
} 
library(lubridate)

# Add factor column to distinguish season within the year:
df$season <- factor(ifelse(3 <= month(df$date) & month(df$date) <= 5, 'Spring',
                           ifelse(6 <= month(df$date) & month(df$date) <= 8, 'Summer',
                                  ifelse(9 <= month(df$date) & month(df$date) <= 11, 'Autumn', 'Winter'))),
                    levels = c('Spring','Summer','Autumn','Winter'))

# Final inspection of the dataframe:
str(df)
sapply(df,class)

# For ease of ggplot executions, store alternative shapes of df via melt() and dcast():
# Load library data.table, installing it beforehand if necessary, for use in the subsequent step
if (!'data.table' %in% installed.packages()) {
    install.packages('data.table')
} 
library(data.table)

# (1) Shorten df.length and expand df.width by having pollutant measures in separate columns
dt_wide <- dcast(as.data.table(df),
                 date + season + temp_avg + precipitation + wind_avg_speed ~ parameter,
                 value.var = 'value')
sapply(dt_wide,class)

# (2) Extend df.length and contract df.width by having weather variables as factor levels in a common column
dt_long <- melt(as.data.table(df),
                id.vars = c('date', 'season', 'parameter','value'),
                measure.vars = c('temp_avg','precipitation','wind_avg_speed'),
                variable.name = 'weather_variable',
                value.name = 'weather_value')
sapply(dt_long,class)


#### 3.DESCRIPTIVE ANALYSIS ####

# Load necessary libraries, installing them beforehand if necessary:
if (!'ggplot2' %in% installed.packages()) {
    install.packages('ggplot2')
} 
library(ggplot2)

if (!'corrplot' %in% installed.packages()) {
    install.packages('corrplot')
} 
library(corrplot)

if (!'gridExtra' %in% installed.packages()) {
    install.packages('gridExtra')
} 
library(gridExtra)

if (!'leaflet' %in% installed.packages()) {
    install.packages('leaflet')
} 
library(leaflet)

# Set the default theme
theme_set(theme_minimal(base_size = 16))

# 3.1 Correlation matrices and scatterplots
# Create a correlation matrix with the dcasted data.table dt_wide
mcor <- cor(dt_wide[, !c('date','season')])
round(mcor, digits = 4)

# Correlation matrix of all variables recorded
corrplot(mcor, tl.srt=45)
# Heatmap of correlations
corrplot(mcor, method="shade", shade.col=NA, tl.col="black", tl.srt=45)
# Heatmap with quantified correlation
mycol <- colorRampPalette(c("#BB4444", "#EE9988", "#FFFFFF", "#77AADD", "#4477AA")) 
corrplot(mcor, method="shade", shade.col=NA, tl.col="black", tl.srt=45,
         col=mycol(200), addCoef.col="black",order="AOE")

# Scatter plot of the relationship of NO2 (feature of interest) with the other parameters and weather variables
sp5 <- ggplot(dt_wide, aes(x = NO2, y = SO2)) + geom_point()
sp6 <- ggplot(dt_wide, aes(x = NO2, y = O3)) + geom_point()
sp7 <- ggplot(dt_wide, aes(x = NO2, y = PM2.5)) + geom_point()
sp8 <- ggplot(dt_wide, aes(x = NO2, y = wind_avg_speed)) + geom_point()
sp9 <- ggplot(dt_wide, aes(x = NO2, y = precipitation)) + geom_point()
sp10 <- ggplot(dt_wide, aes(x = NO2, y = temp_avg)) + geom_point()

grid.arrange(sp5, sp6, sp7, sp8, sp9, sp10, nrow = 3, ncol = 2)

# Alternatively (crossing of all (4x3) parameters with all weather variables)
ggplot(dt_long, aes(x = value, y = weather_value)) + geom_point() + facet_wrap(~ parameter + weather_variable)

# 3.2 Distribution of the 4 parameters 
d1 <- ggplot(df[df$parameter == "SO2",], aes(x = value)) + geom_density(aes(color = parameter))
d2 <- ggplot(df[df$parameter == "NO2",], aes(x = value)) + geom_density(aes(color = parameter))
d3 <- ggplot(df[df$parameter == "PM2.5",], aes(x = value)) + geom_density(aes(color = parameter))
d4 <- ggplot(df[df$parameter == "O3",], aes(x = value)) + geom_density(aes(color = parameter))

grid.arrange(d1, d2, d3, d4, nrow = 2, ncol = 2)

# Alternatively
ggplot(df, aes(x = value)) + geom_density(aes(color = parameter)) + facet_wrap(~parameter)

# Box plot & density chart of each of the 4 parameters in one grid
p1 <- ggplot(df, aes(y = value, x = parameter, colour = parameter)) + geom_boxplot()
p2 <- ggplot(df, aes(x = value, colour = parameter)) + geom_density()

grid.arrange(p1, p2, ncol = 2)

# Boxplot for all 4 pollutants
ggplot(data = df,
       aes(x = parameter, y = value, fill = parameter, colour = parameter)) +
    geom_boxplot(alpha = 0.5)

# Read location of stations and show spatial distribution
station_data <- read_excel("./Stations.xlsx")

leaflet(data = station_data) %>% setView(lng = -3.6826, lat = 40.4144, zoom = 12) %>%
    addProviderTiles(providers$CartoDB.Positron) %>%
    addCircleMarkers(~long, ~lat, color = ~ifelse(Retiro == 1, 'red', 'blue'))

# 3.3 Time series
# Scatter plots of each parameter over timespan 2011-2016 (neutral, no distinction of season)
sp1 <- ggplot(dt_wide, aes(x = date, y = NO2)) + geom_point()
sp2 <- ggplot(dt_wide, aes(x = date, y = SO2)) + geom_point()
sp3 <- ggplot(dt_wide, aes(x = date, y = PM2.5)) + geom_point()
sp4 <- ggplot(dt_wide, aes(x = date, y = O3)) + geom_point()

grid.arrange(sp1, sp2, sp3, sp4, nrow = 2, ncol = 2)

# Alternatively
ggplot(df, aes(x = date, y = value)) + geom_point() + facet_wrap(~parameter)

# Scatter plots of each parameter over timespan 2011-2016 (distinguishing season)
ts1 <- ggplot(dt_wide, aes(x = date, y = NO2)) +
    geom_point(aes(colour = season)) + geom_smooth(method = 'loess') +
    scale_color_manual(values = c('green','yellow2','chocolate3','darkgrey'))
ts2 <- ggplot(dt_wide, aes(x = date, y = SO2)) +
    geom_point(aes(colour = season)) + geom_smooth(method = 'loess') +
    scale_color_manual(values = c('green','yellow2','chocolate3','darkgrey'))
ts3 <- ggplot(dt_wide, aes(x = date, y = PM2.5)) +
    geom_point(aes(colour = season)) + geom_smooth(method = 'loess') +
    scale_color_manual(values = c('green','yellow2','chocolate3','darkgrey'))
ts4 <- ggplot(dt_wide, aes(x = date, y = O3)) +
    geom_point(aes(colour = season)) + geom_smooth(method = 'loess') +
    scale_color_manual(values = c('green','yellow2','chocolate3','darkgrey'))

grid.arrange(ts1, ts2, ts3, ts4, nrow = 2, ncol = 2)

# Alternatively
ggplot(df, aes(x = date, y = value)) +
    geom_point(aes(colour = season)) + geom_smooth(method = 'loess') +
    scale_color_manual(values = c('green','yellow2','chocolate3','darkgrey')) +
    facet_wrap(~parameter)

# Scatter plots of all weather variables over timespan 2011-2016
ts9 <- ggplot(data = dt_wide, aes(x = date, y = temp_avg)) + geom_point() + geom_smooth(method = 'loess')
ts10 <- ggplot(data = dt_wide, aes(x = date, y = precipitation)) + geom_point() + geom_smooth(method = 'loess')
ts11 <- ggplot(data = dt_wide, aes(x = date, y = wind_avg_speed)) + geom_point() + geom_smooth(method = 'loess')

grid.arrange(ts9, ts10, ts11, nrow = 3, ncol = 1)

# Alternatively (less suitable, as weather vars do NOT share units)
ggplot(data = dt_long, aes(x = date, y = weather_value)) +
    geom_point() +
    geom_smooth(method = 'loess') +
    facet_wrap(~weather_variable)

# Wrap of 4 boxplots with all parameters year by year
ggplot(data = df,
       aes(x = factor(year(date)), y = value, fill = factor(year(date)))) +
    geom_boxplot(alpha = 0.5) +
    facet_wrap(~parameter)

# Wrap of 3 boxplots with all weather variables year by year
ggplot(data = dt_long,
       aes(x = factor(year(date)), y = weather_value, fill = factor(year(date)))) +
    geom_boxplot(alpha = 0.5) +
    facet_wrap(~weather_variable)

# Sequence of boxplots for parameter NO2 by seasons over timespan 2011-2016, with lines connecting medians (ugly but useful)
ggplot(dt_wide,
       aes(x = factor(year(date)), y = NO2, fill = season)) +
    geom_boxplot(position = position_dodge(width = 0.9), alpha = 0.5) +
    stat_summary(
        fun.y = median,
        geom = 'line',
        aes(group = season, colour = season),
        position = position_dodge(width = 0.9))


#### 4. MULTI-LINEAR REGRESSION MODEL EXPLAINING VARIABLE NO2 ####

# Define function to perform backward feature elimination, sequentially checking in each cycle if the maximum
# p-value for a variable is above the predefined significance level (default 5%).
# When executing lm(), factor variables are internally unfolded into dummy columns. If one such column were to
# attain the maximum p-value, the entire factor column is dropped.
backwardElimination <- function(dset, sl = 0.05) {
    
    regressor <- lm(formula = NO2 ~ ., data = dset)
    maxP <- max(coef(summary(regressor))[-1, "Pr(>|t|)"])
    
    while (maxP > sl) {
        
        j <- which(coef(summary(regressor))[-1, "Pr(>|t|)"] == maxP)
        
        if (substr(names(j), 1, 6) == 'season') {
            
            dset <- dset[, c('season'):= NULL]
            
        } else {
            
            dset <- dset[, c(names(j)):= NULL]
        }
        regressor <- lm(formula = NO2 ~ ., data = dset)
        maxP <- max(coef(summary(regressor))[-1, "Pr(>|t|)"])
    }
    
    return(regressor)
}

# Execute the function initially considering all variables except date, and display summary of the returned model:
regressor <- backwardElimination(dt_wide[, !c('date')])
regressor2 <- backwardElimination(dt_wide[, !c('date','temp_avg')])
summary(regressor)
summary(regressor2)

# Plot fitted values over the training timespan 2011-2016
ggplot(dt_wide,
       aes(x = date, y = NO2)) +
    geom_point(col = 'darkgray') +
    geom_line(aes(x = date, y = regressor$fitted.values), col = 'blue', alpha = 0.5)

# Residual distribution around 0:
df_residuals <- as.data.frame(regressor$residuals)
colnames(df_residuals) <- c('residual')

ggplot(df_residuals,
       aes(x = residual)) +
    geom_histogram(aes(y = stat(density)), bins = 30, alpha = 0.7, fill = '#333333') +
    geom_density(fill = '#ff4d4d', alpha = 0.5) +
    theme(panel.background = element_rect(fill = '#ffffff')) +
    ggtitle("Residual density with histogram overlay") +
    theme(plot.title = element_text(hjust = 0.5, face = 'bold'))

# Residual homoscedasticity check and qq plot
par(mfrow = c(1, 2))
plot(regressor, which = c(2,1))








