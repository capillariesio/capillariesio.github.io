import sys
import os

allow_multiple_accordion_items_open= True

def metric_accordion_item(title, alias,cpus, nodes, pre):
    if title == "" or alias == "" or cpus == "" or nodes == "":
      print('requires 5 parameters:  "Some title" cfg|runs|cpu|mem|reads|writes 8 4 optional_tf_cfg_file')
      sys.exit()

    if  alias == "runs":
      file_idx="00"
    elif  alias == "cpu":
      file_idx="01"
    elif  alias == "mem":
      file_idx="02"
    elif  alias == "reads":
      file_idx="03"
    elif  alias == "writes":
      file_idx="04"
    elif  alias == "cfg":
      if  "$pre" == "":
        print('Provide either non-cfg alias or optional_tf_cfg_file')
        sys.exit()
    else:
      print(f'Unexpected alias: {alias}')
      sys.exit()
    

    suffix=f'{cpus}-{nodes}-{alias}'

    print(f'          <div class="accordion-item">')
    print(f'            <h2 class="accordion-header" id="heading-{suffix}">')
    print(f'              <button class="accordion-button collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapse-{suffix}" aria-expanded="false" aria-controls="collapse-{suffix}">')
    print(f'                {title}')
    print(f'              </button>')
    print(f'            </h2>')
    if allow_multiple_accordion_items_open:
        print(f'            <div id="collapse-{suffix}" class="accordion-collapse collapse" aria-labelledby="heading-{suffix}">')
    else:
      print(f'            <div id="collapse-{suffix}" class="accordion-collapse collapse" aria-labelledby="heading-{suffix}" data-bs-parent="#accordionTests-{cpus}-{nodes}">')
    print(f'              <div class="accordion-body">')

    if  pre != "":
      if not os.path.exists(pre):
        print(f'File {pre} not found')
        sys.exit()
      with open(pre,"r") as f:
        tf_stats = f.read()
        print(f'      <pre>')
        print(tf_stats)
        print(f'      </pre>')
    else:
      print(f'          <img src="./i/s/c7g.{cpus}/{nodes}/{file_idx}-{alias}.png" class="img-fluid" />')

    print(f'              </div>')
    print(f'            </div>')
    print(f'          </div>')


def test_accordion_item(cpus,nodes,seconds,cost):
    suffix=f'{cpus}-{nodes}'
    print(f'  <div class="accordion-item">')
    print(f'    <h2 class="accordion-header" id="heading-{suffix}">')
    print(f'      <button class="accordion-button color{cpus} collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#collapse-{suffix}" aria-expanded="false" aria-controls="collapse-{suffix}">')
    print(f'        <div class="col-2">aws.arm64.c7g.{cpus}</div>')
    print(f'        <div class="col-3">Cassandra cores {cpus}</div>')
    print(f'        <div class="col-3">Cassandra nodes {nodes}</div>')
    print(f'        <div class="col-2">{seconds} seconds</div>')
    print(f'        <div class="col-1">${cost}</div>')
    print(f'      </button>')
    print(f'    </h2>')
    if allow_multiple_accordion_items_open:
        print(f'    <div id="collapse-{suffix}" class="accordion-collapse collapse" aria-labelledby="heading-{suffix}">')
    else:
      print(f'    <div id="collapse-{suffix}" class="accordion-collapse collapse" aria-labelledby="heading-{suffix}" data-bs-parent="#accordionTests">')
    print(f'      <div class="accordion-body">')
    print(f'        <div class="accordion" id="accordionTests-{suffix}">')
    metric_accordion_item('Terraform config', 'cfg', cpus, nodes, f"./i/s/c7g.{cpus}/{nodes}/tf.txt")
    metric_accordion_item('Test runs', 'runs', cpus, nodes, "")
    metric_accordion_item('CPU usage', 'cpu', cpus, nodes, "")
    metric_accordion_item('Memory usage', 'mem', cpus, nodes, "")
    metric_accordion_item('Cassandra reads', 'reads', cpus, nodes, "")
    metric_accordion_item('Cassandra writes', 'writes', cpus, nodes, "")
    print(f'        </div>')
    print(f'      </div>')
    print(f'    </div>')
    print(f'  </div>')


print(f'<div class="accordion" id="accordionTests">')

test_accordion_item("8", "4", "976", "0.49")
test_accordion_item("8", "8", "578", "0.57")
test_accordion_item("8", "16", "296", "0.58")
test_accordion_item("8", "32", "198", "0.77")

test_accordion_item("16", "4", "503", "0.50")
test_accordion_item("16", "8", "275", "0.54")
test_accordion_item("16", "16", "176", "0.68")

test_accordion_item("32", "4", "270", "0.53")
test_accordion_item("32", "8", "176", "0.68")

test_accordion_item("64", "4", "209", "0.81")

print(f'</div>')

