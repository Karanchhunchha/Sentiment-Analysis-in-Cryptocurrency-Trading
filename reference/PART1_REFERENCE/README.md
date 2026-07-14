# **Solution to MATLAB and Simulink Challenge project <'239'> <'Sentiment Analysis in Cryptocurrency Trading'>**

## **Program Link**  

https://github.com/steven1he/BTC-price-prediction-using-sentimental-analysis
## **Program details**  



### **Overview**
This project aims to predict Bitcoin (BTC) prices using sentiment analysis of cryptocurrency-related text data, combined with historical price data. The workflow includes data preprocessing, feature engineering, model training, and evaluation.

### **Demo**
<p align="center">
    <img alt="result picture" src="https://github.com/steven1he/BTC-price-prediction-using-sentimental-analysis/blob/main/result_picture/prediction_vs_true.png" />
</p>

---

### **Workflow, Directory Structure, Requirements, Usage, and Results**

```plaintext

1. Download Datasets:
   - BTC Tweets Dataset: https://www.kaggle.com/datasets/kaushiksuresh147/bitcoin-tweets
   - BTC Historical Price Data: https://www.kaggle.com/datasets/mczielinski/bitcoin-historical-data#coinbaseUSD_1-min_data_2014-12-01_to_2019-01-09.csv
   - You can simply use the outcome 'filtered_merged_sentiment_price1.csv' for trianing and testing.

2. Run Sentiment Analysis:
   - Execute the script sentimental_score.m to calculate sentiment scores (e.g., maximum, average, variance) for all tweets over the past 90 days, aggregated by minute.

3. Preprocess Historical Data:
   - Use the script shift_time.m to convert timestamps into a human-readable format (year, month, day, hour, minute).

4. Merge Data:
   - Run merge_data.m to combine the historical price data and the sentiment analysis results into a single dataset: merged_file_90days_1min(final).csv.
   - Note: The merged file is already included in the repository for direct use.

5. Train and Test the Model:
   - Run train_test.m to train the prediction model and evaluate its performance.
   - Prediction results are saved as plots in the result_picture/ directory.

Directory Structure:
BTC-price-prediction-using-sentimental-analysis/
├── sentimental_score.m        # Sentiment score calculation script
├── shift_time.m               # Timestamp conversion script
├── merge_data.m               # Data merging script
├── train_test.m               # Model training and testing script
├── merged_file_90days_1min(final).csv  # Processed dataset for training
├── result_picture/            # Directory containing prediction results

Requirements:
- MATLAB R2021a or later
- Required MATLAB Toolboxes:
  - Statistics and Machine Learning Toolbox
  - Deep Learning Toolbox

Usage:
1. Clone the repository:
   git clone https://github.com/steven1he/BTC-price-prediction-using-sentimental-analysis.git
   cd BTC-price-prediction-using-sentimental-analysis

2. Run the following MATLAB scripts in sequence:
   matlab sentimental_score.m
   matlab shift_time.m
   matlab merge_data.m
   matlab train_test.m

Results:
- The final processed dataset: merged_file_90days_1min(final).csv
- Prediction results, including plots of actual vs. predicted prices, are saved in the result_picture/ directory.
