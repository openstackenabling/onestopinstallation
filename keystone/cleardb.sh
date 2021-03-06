#!/usr/bin/env bash
#
#    Copyright (C) 2013 Intel Corporation.  All rights reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
set -o xtrace

source $STACK_DIR/localrc

mysql -uroot -p$MYSQL_PASSWD -e "DROP DATABASE IF EXISTS keystone;"
mysql -uroot -p$MYSQL_PASSWD -e "CREATE DATABASE keystone;"
mysql -uroot -p$MYSQL_PASSWD -e "GRANT ALL ON keystone.* TO '$KEYSTONE_DB_USER'@'%' IDENTIFIED BY '$KEYSTONE_DB_PASSWD';"

keystone-manage db_sync

chmod +x $STACK_DIR/keystone/keystone_basic.sh
chmod +x $STACK_DIR/keystone/keystone_endpoints_basic.sh

$STACK_DIR/keystone/keystone_basic.sh
$STACK_DIR/keystone/keystone_endpoints_basic.sh