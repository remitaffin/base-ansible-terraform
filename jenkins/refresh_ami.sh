#!/bin/bash

# Get variables from terraform.tfvars
variables_to_find="aws_profile
dbname
dbuser
dbpassword"

for variable_name in $variables_to_find; do
    variable_name_caps=$(echo $variable_name | tr [a-z] [A-Z]);
    value=$(grep -i $variable_name terraform.tfvars | cut -d\" -f2);
    export $variable_name_caps=$value;
done

packer build packer.json
