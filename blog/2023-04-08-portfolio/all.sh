#!/bin/sh

table2html()
{
    # $1 table name
    # $2 node name in the script
    # $3 script file path
    # $4 output file
    echo '<div class="row">' >> $4.html
    echo "<h2>$2</h2>" >> $4.html
    echo "<h3>Script node $2:</h3>" >> $4.html
    python ./node_json_2_html.py $2 < $3 >> $4.html
    echo "<h3>Script node $2 produces Cassandra table $1:</h3>" >> $4.html
    docker exec -it capillaries_cassandra1 cqlsh --no-color  -e "use portfolio_quicktest;COPY $1_00001 TO stdout with HEADER=TRUE;" | python ./table_2_html.py >> $4.html
    echo '</div>' >> $4.html
}
csv2html()
{
    # $1 csv path
    # $2 node name in the script
    # $3 script file path
    # $4 output file
    echo '<div class="row">' >> $4.html
    echo "<h2>$2</h2>" >> $4.html
    echo "<h3>Script node $2:</h3>" >> $4.html
    python ./node_json_2_html.py $2 < $3 >> $4.html
    echo "<h3>Script node $2 produces data file:</h3>" >> $4.html
    cat $1 | python ./table_2_html.py >> $4.html
    echo '</div>' >> $4.html
}

echo '<html>\n<head><link rel="stylesheet" href="../../css/bootstrap.min.css">\n<link rel="stylesheet" href="../../css/overrides.css">\n</head>\n<body>\n' > nodes.html
echo '<div class="container">\n' >> nodes.html

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

table2html txns 1_read_txns $script_json nodes
table2html accounts 1_read_accounts $script_json nodes
table2html period_holdings 1_read_period_holdings $script_json nodes
table2html account_txns 2_account_txns_outer $script_json nodes
table2html account_period_holdings 2_account_period_holdings_outer $script_json nodes
table2html account_period_activity 3_build_account_period_activity $script_json nodes
table2html account_period_perf 4_calc_account_period_perf $script_json nodes
table2html account_period_perf_by_period 5_tag_by_period $script_json nodes
table2html account_period_perf_by_period_sector 5_tag_by_sector $script_json nodes
table2html account_period_sector_twr_cagr 6_perf_json_to_columns $script_json nodes

csv2html "../../../capillaries/test/data/out/portfolio_quicktest/account_period_sector_perf_baseline.csv" 7_file_account_period_sector_perf $script_json nodes
csv2html "../../../capillaries/test/data/out/portfolio_quicktest/account_year_perf_baseline.csv" 7_file_account_year_perf $script_json nodes

echo '</div></body>\n</head>' >> nodes.html
