#!/bin/sh

html()
{
    # $1 table name
    # $2 node name in the script
    # $3 script file path
    # $4 output file
    echo "<h2>$2</h2>" >> $4.html
    echo "<h3>Script node $2:</h3>" >> $4.html
    python ./node_json_2_html.py $2 < $3 >> $4.html
    echo "<h3>Script node $2 produces Cassandra table $1:</h3>" >> $4.html
    docker exec -it capillaries_cassandra1 cqlsh --no-color  -e "use portfolio_quicktest;COPY $1_00001 TO stdout with HEADER=TRUE;" | python ./table_2_html.py >> $4.html
}

echo '<html>\n<head><link rel="stylesheet" href="../../css/bootstrap.min.css">\n<link rel="stylesheet" href="../../css/overrides.css">\n</head>\n<body><div class="container">\n' > nodes.html
script_json="../../../capillaries/test/data/cfg/portfolio_quicktest/script.json"
html txns 1_read_txns $script_json nodes
html accounts 1_read_accounts $script_json nodes
html period_holdings 1_read_period_holdings $script_json nodes
html account_txns 2_account_txns_outer $script_json nodes
html account_period_holdings 2_account_period_holdings_outer $script_json nodes
html account_period_activity 3_build_account_period_activity $script_json nodes
html account_period_perf 4_calc_account_period_perf $script_json nodes
html account_period_perf_by_period 5_tag_by_period $script_json nodes
html account_period_perf_by_period_sector 5_tag_by_sector $script_json nodes
html account_period_sector_twr_cagr 6_perf_json_to_columns $script_json nodes
echo '</div></body>\n</head>' >> nodes.html
