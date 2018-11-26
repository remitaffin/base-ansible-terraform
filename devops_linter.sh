#!/bin/bash

# Test terraform syntax
echo -e "  >> Running 'terraform validate'..."
terraform validate
if [ $? -eq 0 ]; then
  echo -e "Success!\n\n"
else
  echo -e "Error!\n\n"
  exit
fi

# Test ansible syntax
echo -e "  >> Running 'ansible-playbook prod_myapp.yml --syntax-check'..."
ansible-playbook \
  -i ansible/aws_hosts \
  ansible/prod_myapp.yml \
  --extra-vars "hostgroup=prod-myapp" \
  --syntax-check \
   --vault-password-file ansible/.ansiblevaultpass
if [ $? -eq 0 ]; then
  echo -e "Success!\n\n"
else
  echo -e "Error!\n\n"
  exit
fi
