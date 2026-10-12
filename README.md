# Solar Power Generation Prediction System

A beginner-friendly R and Shiny dashboard for exploring daily solar generation, fitting a linear regression model from weather history, and estimating generation for entered weather conditions.

> The included CSV is **simulated demonstration data**. It is not measured from a real solar installation and cannot establish real-world prediction accuracy. Replace it with your own verified historical data before using the predictions for decisions.

**GitHub repository description:** Interactive R Shiny dashboard for solar-generation exploration and weather-based daily kWh predictions using linear regression.

## Problem and objectives

Solar output changes with weather. This project gives a small solar operator or student one place to inspect generation history, explore weather relationships, train a transparent baseline model, and compare estimates with held-out observations. It is a teaching and analysis tool, not a production forecasting service.

## Features

- Summary of total, average, and highest daily generation, plus the latest prediction.
- CSV upload, required-column checks, date and number parsing, row cleaning, and an explicit active-data label.
- Daily and monthly generation charts, weather-versus-generation chart, and held-out actual-versus-predicted chart. Plotly controls support hover and zoom.
- Linear regression (`lm`) using supported weather fields present in the active CSV.
- Chronological 80/20 training/test split; training-only median imputation; test-set MAE and RMSE.
- Prediction input form with finite-number checks and a non-negative output floor.
- CSV downloads for a prediction with its input values and for historical summary statistics.

## Project files

```text
SolarPowerGeneration/
|-- app.R
|-- data/
|   `-- sample_solar_data.csv
|-- .gitignore
`-- README.md
```

`app.R` contains the UI, input validation, data cleaning, model, plots, and downloads. `data/sample_solar_data.csv` is the clearly labeled simulated starter dataset. `.gitignore` excludes local R state and the local rsconnect configuration folder; do not commit credentials.

## Requirements

- Windows 10/11
- R (install the current version from [CRAN](https://cran.r-project.org/))
- RStudio Desktop (install from [Posit](https://posit.co/download/rstudio-desktop/))
- R packages: `shiny`, `dplyr`, `ggplot2`, `plotly`

No Python, external API, or separate backend is used.

## Quick start (run the app)

From the project folder in R or RStudio:

```r
install.packages(c("shiny", "dplyr", "ggplot2", "plotly"))

# Change to the project folder if needed
setwd("C:/path/to/SolarPowerGeneration")

# Start the app
shiny::runApp()
```

From a terminal or command prompt without opening RStudio:

```powershell
cd "C:/path/to/SolarPowerGeneration"
Rscript -e "shiny::runApp(launch.browser = FALSE, host = '127.0.0.1', port = 3838)"
```

The app will start locally at http://127.0.0.1:3838.

## Windows setup and run

1. Install R, then install and open RStudio.
2. Create a folder named `SolarPowerGeneration` and put `app.R`, `.gitignore`, `README.md`, and the `data` folder with its CSV inside it. Alternatively, open this project folder directly in RStudio with **File > Open Project** (or use **File > Open File** and select `app.R`).
3. In the RStudio Console, install the dependencies once:

   ```r
   install.packages(c("shiny", "dplyr", "ggplot2", "plotly"))
   ```

4. Set RStudio's working directory to the project folder (**Session > Set Working Directory > To Source File Location**) or open the folder as an RStudio Project. The app expects `data/sample_solar_data.csv` relative to that folder.
5. Open `app.R` and click **Run App**, or run this in the Console from the project folder:

   ```r
   shiny::runApp()
   ```

6. On **Overview**, confirm the active dataset is labeled `Included simulated sample data`. Explore the charts and date filter. On **Predict**, enter weather values and click **Predict generation**. On **Data & reports**, upload a CSV or click **Use included sample dataset**.
7. Try both download buttons: prediction inputs and result are exported together; the historical report contains source, usable row count, date span, total, average, and highest generation.

### Dataset format

The CSV must contain `date` and `generation_kwh`. Column names are case-insensitive and spaces/punctuation are normalized to underscores. Use dates such as `YYYY-MM-DD` for unambiguous parsing and generation values in kWh. Optional numeric columns recognized by the model are `solar_radiation` (W/m2), `cloud_cover` (percent), `temperature` (C), `humidity` (percent), `wind_speed` (km/h), `precipitation` (mm), and `sunshine_hours`. Other columns are ignored. Cloud cover is validated from 0 to 100 when entered for prediction.

Rows with invalid dates, missing/non-numeric generation, or negative generation are excluded, and the app reports how many were excluded. Missing or non-numeric optional weather values are treated as missing and filled with the corresponding **training-set median**. Features with no usable variation in the training set are skipped. An upload with missing required columns is rejected; the previously active dataset remains selected and the error is shown rather than silently switching to sample data. A model needs at least five usable rows and enough training rows for its selected features; otherwise the app explains what is missing.

## How the model works

The app sorts valid observations by date. It uses the earliest 80% of rows for training and the latest 20% for testing, preserving time order so future observations do not train a model evaluated on earlier data. Each available supported weather column is a predictor in an ordinary multiple linear regression fitted with `lm()`. Missing weather values are imputed using medians calculated only on the training rows, then those same medians are applied to test rows and user inputs. Predictions below zero are floored at zero.

Mean absolute error (MAE) is the average absolute test-set error in kWh. Root mean squared error (RMSE) is the square root of the average squared test-set error in kWh; it gives larger errors more weight. Both metrics are calculated on the held-out chronological rows. Small or unrepresentative histories, missing weather observations, sensor errors, seasonal shifts, and a linear model's assumptions can all affect results. Metrics from the simulated starter CSV are for demonstrating calculations only, not evidence of real-world accuracy.

## How the Shiny app is organized

`ui` declares navigation tabs, charts, forms, tables, and downloads. Shiny sends browser input values to the R `server` function. Reactive expressions rerun data summaries, model fitting, and plots when the active dataset or controls change. The prediction button checks the entered values, supplies them to the fitted model, and presents the output; download handlers write the result or summary as CSV in the browser.

## Troubleshooting

- **`there is no package called ...`**: Run the `install.packages(...)` command above, then restart RStudio.
- **Sample CSV not found**: Set the working directory to the project folder, or open the folder as an RStudio Project; verify the `data` subfolder and filename.
- **Upload rejected**: Ensure the CSV contains `date` and `generation_kwh`; use `YYYY-MM-DD` dates and numeric generation values.
- **Model unavailable**: Add more valid historical rows and at least one supported numeric weather column that varies over the training period. Remove redundant/constant weather fields if test predictions cannot be computed.
- **App does not open in a browser**: In RStudio, use **Run App** and check the Console for the first error; confirm the app's folder is the working directory.

## Deploy to shinyapps.io

1. Create an account at [shinyapps.io](https://www.shinyapps.io/) and sign in.
2. Install the deployment package in RStudio:

   ```r
   install.packages("rsconnect")
   ```

3. In the shinyapps.io dashboard, open **Account > Tokens**, create a token, and use the dashboard's generated `rsconnect::setAccountInfo(...)` command in the **RStudio Console**. Do not paste token or secret values into `app.R`, README, Git, screenshots, or a shared script. The command saves account configuration locally outside the app source; keep that configuration private. If your organization provides a credential manager, use it according to its guidance.
4. From the project directory, publish with the RStudio **Publish** button, or run:

   ```r
   rsconnect::deployApp(appDir = ".")
   ```

   The first deployment may prompt you to choose an account and application name. The `rsconnect/` folder is ignored by Git because it can contain local deployment configuration.
5. Wait for deployment to finish, open the public URL shown by RStudio/rsconnect, and test the overview, upload, prediction, and downloads. The app bundles its CSV and installs declared package dependencies on the hosting service.
6. After editing and testing the code, run the same `deployApp(appDir = ".")` command (or publish again in RStudio) to update the deployed app.

## Development phases

1. **Environment and structure:** install R/RStudio and create the four project items shown above.
2. **Starter data and uploads:** inspect the simulated CSV; upload checks are in `read_and_validate_csv()` in `app.R`.
3. **Cleaning and exploration:** required values are checked, bad rows excluded, and the Overview charts summarize the active data.
4. **Training and evaluation:** the `model_result` reactive block in `app.R` splits by date, imputes using training data, fits `lm()`, and calculates test MAE/RMSE.
5. **Dashboard:** the `ui` object defines Overview, Predict, and Data & reports tabs; `server` supplies their reactive content.
6. **Predictions and reports:** use the Predict tab and the CSV download controls in the app.
7. **Local test:** follow Windows setup, upload a small test CSV, verify a valid and invalid upload, make a prediction, and download both reports.
8. **Online deployment:** follow the shinyapps.io steps after local testing.
9. **GitHub documentation:** include these files in the repository, review `.gitignore`, and never commit account tokens or secrets.

## Limitations and future improvements

This is a compact baseline using linear regression and daily records. It does not account for panel orientation, equipment faults, shading, location, or forecast uncertainty. Consider validating with a larger real dataset, adding time-series cross-validation and prediction intervals, supporting explicit units and site metadata, and comparing against seasonal or tree-based models before relying on it operationally.
