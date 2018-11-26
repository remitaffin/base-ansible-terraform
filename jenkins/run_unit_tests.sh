#!/bin/bash

set -e

export PYTHONUNBUFFERED=1

rm -rf virtualenv
virtualenv virtualenv
virtualenv/bin/pip install -r requirements.txt
cat <<EOF > virtualenv/bin/postactivate
#!/bin/bash
export SECRET_KEY='secret-key'
export DB_USER=''
export DB_PASS=''
export DB_HOST=''
export DB_DB=''
EOF

. virtualenv/bin/activate
. virtualenv/bin/postactivate
python tests.py
