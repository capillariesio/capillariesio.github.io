#!/bin/bash

source ./util.sh

echo '<html><head><link rel="stylesheet" href="../../css/bootstrap.min.css"><link rel="stylesheet" href="../../css/overrides.css"></head><body>' > nodes.html
echo '<div class="container">' >> nodes.html

echo "<div class="row"><h1>fannie_mae_quicktest script and data</h1></div>" >> nodes.html

echo '<div class="row">' >> nodes.html
echo "<h2>Input files</h2>" >> nodes.html
echo "<h3>Payments</h3>" >> nodes.html
../../../capillaries/build/linux/amd64/capiparquet cat ../../../capillaries/test/data/in/fannie_mae_quicktest/CAS_2023_R08_G1_20231020_000.parquet | python ./table_2_html.py >> nodes.html
echo '</div>' >> nodes.html

script_json="../../../capillaries/test/data/cfg/fannie_mae_quicktest/script.json"

table2html payments 01_read_payments $script_json nodes fannie_mae_quicktest
table2html load_ids 02_loan_ids $script_json nodes fannie_mae_quicktest
table2html deal_names 02_deal_names $script_json nodes fannie_mae_quicktest
table2html deal_total_upbs 03_deal_total_upbs $script_json nodes fannie_mae_quicktest
table2html loan_payment_summaries 04_loan_payment_summaries $script_json nodes fannie_mae_quicktest
table2html loan_summaries_calculated 04_loan_summaries_calculated $script_json nodes fannie_mae_quicktest
table2html deal_seller_summaries 05_deal_seller_summaries $script_json nodes fannie_mae_quicktest
table2html deal_summaries 05_deal_summaries $script_json nodes fannie_mae_quicktest

parquet2html "../../../capillaries/test/data/out/fannie_mae_quicktest/loan_summaries_calculated_baseline.parquet" 04_write_file_loan_summaries_calculated $script_json nodes
parquet2html "../../../capillaries/test/data/out/fannie_mae_quicktest/deal_seller_summaries_baseline.parquet" 05_write_file_deal_seller_summaries $script_json nodes
parquet2html "../../../capillaries/test/data/out/fannie_mae_quicktest/deal_summaries_baseline.parquet" 05_write_file_deal_summaries $script_json nodes

echo '</div></body></head>' >> nodes.html
