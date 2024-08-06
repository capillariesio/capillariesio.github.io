#!/bin/bash

source ./util.sh

echo '<html><head><link rel="stylesheet" href="../../css/bootstrap.min.css"><link rel="stylesheet" href="../../css/overrides.css"></head><body>' > nodes.html
echo '<div class="container">' >> nodes.html

echo "<div class="row"><h1>portfolio_quicktest script and data</h1></div>" >> nodes.html

echo '<div class="row">' >> nodes.html
echo "<h2>Input files</h2>" >> nodes.html
echo "<h3>Accounts</h3>" >> nodes.html
cat ../../../capillaries/test/data/in/portfolio_quicktest/accounts.csv | python ./table_2_html.py >> nodes.html
echo "<h3>Transactions</h3>" >> nodes.html
cat ../../../capillaries/test/data/in/portfolio_quicktest/txns.csv | python ./table_2_html.py >> nodes.html
echo "<h3>Holdings</h3>" >> nodes.html
cat ../../../capillaries/test/data/in/portfolio_quicktest/holdings.csv | python ./table_2_html.py >> nodes.html
echo '</div>' >> nodes.html

script_json="../../../capillaries/test/data/cfg/portfolio_quicktest/script.json"

table2html txns 1_read_txns $script_json nodes portfolio_quicktest
table2html accounts 1_read_accounts $script_json nodes portfolio_quicktest
table2html period_holdings 1_read_period_holdings $script_json nodes portfolio_quicktest
table2html account_txns 2_account_txns_outer $script_json nodes portfolio_quicktest
table2html account_period_holdings 2_account_period_holdings_outer $script_json nodes portfolio_quicktest
table2html account_period_activity 3_build_account_period_activity $script_json nodes portfolio_quicktest
table2html account_period_perf 4_calc_account_period_perf $script_json nodes portfolio_quicktest
table2html account_period_perf_by_period 5_tag_by_period $script_json nodes portfolio_quicktest
table2html account_period_perf_by_period_sector 5_tag_by_sector $script_json nodes portfolio_quicktest
table2html account_period_sector_twr_cagr 6_perf_json_to_columns $script_json nodes portfolio_quicktest

csv2html "../../../capillaries/test/data/out/portfolio_quicktest/account_period_sector_perf_baseline.csv" 7_file_account_period_sector_perf $script_json nodes
csv2html "../../../capillaries/test/data/out/portfolio_quicktest/account_year_perf_baseline.csv" 7_file_account_year_perf $script_json nodes

echo '</div></body></head>' >> nodes.html
