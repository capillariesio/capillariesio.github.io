#!/bin/bash

metric_accordion_item()
{
    title=$1
    alias=$2
    cpus=$3
    nodes=$4
    pre=$5

    if [[ "$title" = "" || "$alias" = "" || "$cpus" = "" || "$nodes" = "" ]]; then
    echo $(basename "$0") requires 5 parameters:  "Some title" cfg|runs|cpu|mem|reads|writes 8 4 optional_tf_cfg_file
    exit 1
    fi

    if [[ "$alias" = "runs" ]]; then
    file_idx="00"
    elif [[ "$alias" = "cpu" ]]; then
    file_idx="01"
    elif [[ "$alias" = "mem" ]]; then
    file_idx="02"
    elif [[ "$alias" = "reads" ]]; then
    file_idx="03"
    elif [[ "$alias" = "writes" ]]; then
    file_idx="04"
    elif [[ "$alias" = "cfg" ]]; then
    if [[ "$pre" = "" ]]; then
        echo Provide either non-cfg alias or optional_tf_cfg_file
        exit 1
    fi
    else
    echo Unexpected alias: $alias
    exit 1
    fi

    suffix=$cpus-$nodes-$alias

    echo \<div class=\"accordion-item\"\>
    echo   \<h2 class=\"accordion-header\" id=\"heading-$suffix\"\>
    echo     \<button class=\"accordion-button collapsed\" type=\"button\" data-bs-toggle=\"collapse\" data-bs-target=\"#collapse-$suffix\" aria-expanded=\"false\" aria-controls=\"collapse-$suffix\"\>
    echo       $title
    echo     \</button\>
    echo   \</h2\>
    echo   \<div id=\"collapse-$suffix\" class=\"accordion-collapse collapse\" aria-labelledby=\"heading-$suffix\" data-bs-parent=\"#accordionTests-$cpus-$nodes\"\>
    echo     \<div class=\"accordion-body\"\>

    if [[ "$pre" != "" ]]; then
    if [[ ! -f "$pre" ]]; then
        echo File $pre not found
        exit 1
    fi
    echo       \<pre\>
    cat $pre
    echo       \</pre\>
    else
    echo \<img src=\"./i/s/c7g.$cpus/$nodes/$file_idx-$alias.png\" class=\"img-fluid\" /\>
    fi

    echo     \</div\>
    echo   \</div\>
    echo \</div\>
}

test_accordion_item()
{
    local cpus=$1
    local nodes=$2
    local seconds=$3
    local cost=$4

    suffix=$cpus-$nodes
    echo \<div class=\"accordion-item\"\>
    echo   \<h2 class=\"accordion-header\" id=\"heading-$suffix\"\>
    echo     \<button class=\"accordion-button color$cpus collapsed\" type=\"button\" data-bs-toggle=\"collapse\" data-bs-target=\"#collapse-$suffix\" aria-expanded=\"false\" aria-controls=\"collapse-$suffix\"\>
    echo       \<div class=\"col-2\"\>aws.arm64.c7g.$cpus\</div\>
    echo       \<div class=\"col-3\"\>Cassandra cores $cpus\</div\>
    echo       \<div class=\"col-3\"\>Cassandra nodes $nodes\</div\>
    echo       \<div class=\"col-2\"\>$seconds seconds\</div\>
    echo       \<div class=\"col-1\"\>\$$cost\</div\>
    echo     \</button\>
    echo   \</h2\>
    echo   \<div id=\"collapse-$suffix\" class=\"accordion-collapse collapse\" aria-labelledby=\"heading-$suffix\" data-bs-parent=\"#accordionTests\"\>
    echo     \<div class=\"accordion-body\"\>
    echo       \<div class=\"accordion\" id=\"accordionTests-$suffix\"\>
    echo $(metric_accordion_item 'Terraform config' cfg $cpus $nodes ./i/s/c7g.$cpus/$nodes/tf.txt)
    echo       \</div\>
    echo     \</div\>
    echo   \</div\>
    echo \</div\>
}

echo \<div class=\"accordion\" id=\"accordionTests\"\>
echo $(test_accordion_item 8 4 976 0.49)
echo \</div\>

# ./accordion-subitem.sh "Terraform config" cfg 8 4 ./i/s/c7g.8/4/tf.txt
# ./accordion-subitem.sh "Test runs" runs 8 4
# ./accordion-subitem.sh "CPU usage" cpu 8 4
# ./accordion-subitem.sh "Memory usage" mem 8 4
# ./accordion-subitem.sh "Cassandra reads" reads 8 4
# ./accordion-subitem.sh "Cassandra writes" writes 8 4
