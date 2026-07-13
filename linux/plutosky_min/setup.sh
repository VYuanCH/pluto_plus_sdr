#!/bin/bash
set -e

PROJ="$(pwd -P)"

sed -i '/CONFIG_USER_LAYER_[0-9]*=/d' project-spec/configs/config

cat >> project-spec/configs/config <<EOF
CONFIG_USER_LAYER_0="$PROJ/external/meta-adi/meta-adi-xilinx"
EOF

echo "Added meta-adi layers using absolute project path:"
grep CONFIG_USER_LAYER project-spec/configs/config
