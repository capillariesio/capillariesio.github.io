#!/bin/sh

table2html()
{
    # $1 table name
    # $2 node name in the script
    # $3 script file path
    # $4 output file
    # $5 keyspace
    echo '<div class="row">' >> $4.html
    echo "<h2>$2</h2>" >> $4.html
    echo "<h3>Script node $2:</h3>" >> $4.html
    python ./node_json_2_html.py $2 < $3 >> $4.html
    echo "<h3>Script node $2 produces Cassandra table $1:</h3>" >> $4.html
    docker exec -it capillaries_cassandra1 cqlsh --no-color  -e "use $5;COPY $1_00001 TO stdout with HEADER=TRUE;" | python ./table_2_html.py >> $4.html
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

parquet2html()
{
    # $1 parquet path
    # $2 node name in the script
    # $3 script file path
    # $4 output file
    echo '<div class="row">' >> $4.html
    echo "<h2>$2</h2>" >> $4.html
    echo "<h3>Script node $2:</h3>" >> $4.html
    python ./node_json_2_html.py $2 < $3 >> $4.html
    echo "<h3>Script node $2 produces data file:</h3>" >> $4.html
    ../../../capillaries/build/linux/amd64/capiparquet cat $1 | python ./table_2_html.py >> $4.html
    echo '</div>' >> $4.html
}