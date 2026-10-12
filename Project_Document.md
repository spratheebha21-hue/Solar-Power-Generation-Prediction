# Solar Power Generation Prediction System

## 1. Introduction

The Solar Power Generation Prediction System is a beginner-friendly R and Shiny dashboard designed to help users explore daily solar generation data, understand weather-related patterns, and estimate electricity output from weather conditions. The project is intended for learning, analysis, and experimentation rather than operational forecasting in a real production environment.

The system reads a CSV file containing historical daily records, validates the input data, fits a linear regression model, summarizes generation trends, and creates predictions for new weather inputs. It is built around a simple, transparent workflow that is easy to understand and modify. This makes it suitable for students, small renewable-energy operators, and anyone interested in using basic data analysis to study solar generation behavior.

The application emphasizes clarity and accessibility. Users can upload their own CSV data, compare it with the included sample dataset, inspect charts and summary statistics, and observe how model performance changes based on available weather variables and data quality.

## 2. Problem Statement and Objectives

Solar electricity generation is strongly influenced by weather and environmental conditions such as sunlight intensity, cloud cover, temperature, humidity, and wind. Understanding these relationships can help estimate how much electricity will be generated on a given day. However, building a useful prediction model requires historical data, valid preprocessing, and careful evaluation.

This project addresses that need by providing a simple dashboard that does the following:

- Explores historical daily solar generation data.
- Visualizes trends over time and by month.
- Examines relationships between generation and weather variables.
- Trains a baseline prediction model using multiple linear regression.
- Evaluates model performance on a held-out test dataset.
- Allows users to input new weather conditions and estimate expected generation.

The primary goal is to provide a practical teaching tool that makes weather-based forecasting easy to understand without requiring advanced infrastructure, APIs, or a separate backend.

## 3. Project Scope and Features

The application includes the following key features:

- Summary cards for total generation, average generation, maximum generation, and latest prediction
- CSV upload with validation for required columns and data types
- Automatic normalization of column names to handle common spreadsheet naming variations
- Data cleaning for invalid dates, missing generation values, negative generation values, and unsupported formats
- Daily and monthly generation charts
- Weather-versus-generation analysis
- Prediction page for entering weather inputs and computing estimated generation
- Chronological 80/20 train/test split for evaluating model performance
- Median imputation for missing weather data using training-set statistics only
- Model evaluation metrics including MAE and RMSE
- Download options for prediction output and historical summaries

The app supports the following weather variables when present in the dataset:

- solar_radiation
- cloud_cover
- temperature
- humidity
- wind_speed
- precipitation
- sunshine_hours

These fields are used as predictors in the regression model when they are present and usable.

## 4. Methodology

### Data Preparation

The app reads the active dataset and checks for the required columns: `date` and `generation_kwh`. It normalizes field names so that labels like `Generation (kWh)` or `Date ` are handled correctly. It then converts date fields to a consistent format and ensures generation values are numeric and non-negative.

Rows with invalid dates, missing generation values, non-numeric generation values, or negative generation values are excluded. The app tracks how many rows were excluded and presents this information to the user.

### Model Training

The app sorts valid observations chronologically and uses the earliest 80% of records for training and the latest 20% for testing. This maintains time order and prevents future data from leaking into the training set.

Missing optional weather values are imputed using medians computed only from the training set. The same medians are then applied to the test set and future prediction inputs to keep the process consistent and realistic.

A multiple linear regression model is fitted using `lm()`. The model uses all supported weather variables available in the active dataset. Features that show no usable variation in the training set are skipped to avoid degenerate predictors.

### Prediction and Evaluation

Once the model is fitted, users can enter weather values for a new day. The app checks whether inputs are numeric and finite, validates cloud cover when provided, and ensures forecast output is not negative by applying a floor of zero.

Model performance is evaluated using:

- Mean Absolute Error (MAE): the average absolute difference between actual and predicted test-set values
- Root Mean Squared Error (RMSE): a metric that gives more weight to larger errors

These metrics provide a transparent baseline for how well the model performs on held-out observations.

## 5. System Architecture

The project is a single-file Shiny application in `app.R`. It contains the complete user interface, data processing logic, model fitting logic, chart rendering, and download handlers.

The app is organized into three main sections:

1. Overview tab
   - Summary cards
   - Daily generation chart
   - Monthly generation chart
   - Weather vs generation chart

2. Predict tab
   - Weather input form
   - Model-based forecast result
   - Actual vs predicted chart
   - Performance metrics table

3. Data & reports tab
   - CSV upload
   - Active dataset indicator
   - Cleaned historical records table
   - Download summary report

The application uses `shiny`, `dplyr`, `ggplot2`, and `plotly` to deliver a simple but effective interactive dashboard.

## 6. Requirements and Setup

### Requirements

- Windows 10/11
- R from CRAN
- RStudio Desktop
- R packages:
  - `shiny`
  - `dplyr`
  - `ggplot2`
  - `plotly`

### How to Run

1. Install R and RStudio.
2. Open the project folder in RStudio.
3. Install dependencies:

```r
install.packages(c("shiny", "dplyr", "ggplot2", "plotly"))
```

4. Set the working directory to the project folder or open the folder as an R project.
5. Run the Shiny app:

```r
shiny::runApp()
```

The app should load in the browser or in the RStudio viewer at a local Shiny port.

## 7. Data and Limitations

The included dataset is a simulated sample and is not based on real measured solar-generation data. It is meant only to demonstrate the workflow and model calculations. For actual forecasting use, a verified dataset from a real system is required.

The project also has some important limitations:

- It uses a simple linear regression model, which may not capture nonlinear effects.
- The model depends on data quality and coverage.
- Missing weather observations can reduce predictive performance.
- Small or unrepresentative datasets may generate weak or unstable results.
- Seasonal changes and changing environmental conditions can affect model reliability.

This is why the application is presented as an educational and exploratory project, not a production-grade forecasting service.

## 8. Conclusion

The Solar Power Generation Prediction System provides a practical and approachable way to study the relationship between weather and solar output. By combining interactive visualization, structured data validation, and linear regression modeling, it gives users a clear view of how a basic forecasting model can be built and evaluated.

The project is especially useful for educational purposes, small demonstrations, and exploratory analysis. It demonstrates the full workflow of preparing data, training a model, testing accuracy, and generating predictions in a user-friendly interface.

Through its simple structure and transparent methods, the project helps users build intuition about time-series data analysis, weather-based forecasting, and the role of data quality in model performance.
