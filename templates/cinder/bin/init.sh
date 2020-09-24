#!/bin//bash
#
# Copyright 2020 Red Hat Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
set -ex

# This script generates the nova.conf/logging.conf file and
# copies the result to the ephemeral /var/lib/config-data/merged volume.
#
# Secrets are obtained from ENV variables.
export Database=${ApiDatabase:-"cinder"}
export DatabaseHost=${DatabaseHost:?"Please specify a DatabaseHost variable."}
export CinderKeystoneAuthPassword=${CinderKeystoneAuthPassword:?"Please specify a CinderKeystoneAuthPassword variable."}
export NovaKeystoneAuthPassword=${NovaKeystoneAuthPassword:?"Please specify a NovaKeystoneAuthPassword variable."}
export DatabasePassword=${DatabasePassword:?"Please specify a DatabasePassword variable."}
export TransportURL=${TransportURL:?"Please specify a TransportURL variable."}

function merge_config_dir {
  echo merge config dir $1
  for conf in $(find $1 -type f)
  do
    conf_base=$(basename $conf)

    # If CFG already exist in ../merged and is not a json file,
    # or nfs_shares we expect for now it can be merged using crudini.
    # Else, just copy the full file.
    if [[ -f /var/lib/config-data/merged/${conf_base} && ${conf_base} != *.json && ${conf_base} != nfs_shares ]]; then
      echo merging ${conf} into /var/lib/config-data/merged/${conf_base}
      crudini --merge /var/lib/config-data/merged/${conf_base} < ${conf}
    else
      echo copy ${conf} to /var/lib/config-data/merged/
      cp -f ${conf} /var/lib/config-data/merged/
    fi
  done
}

# Copy default service config from container image as base
cp -a /etc/cinder/cinder.conf /var/lib/config-data/merged/cinder.conf

# Merge all templates from config-data, config-data-custom and volume-config-data-custom CMs
for dir in /var/lib/config-data/default /var/lib/config-data/custom /var/lib/config-data/volume-custom
do
  # merge config files if the config mount exists (e.g. volume-config-data-custom only used for cinder-volume)
  if [[ -d ${dir} ]]; then
    merge_config_dir ${dir}
  fi
done

# set secrets
crudini --set /var/lib/config-data/merged/cinder.conf DEFAULT transport_url $TransportURL
crudini --set /var/lib/config-data/merged/cinder.conf database connection mysql+pymysql://$Database:$DatabasePassword@$DatabaseHost/$Database
crudini --set /var/lib/config-data/merged/cinder.conf keystone_authtoken password $CinderKeystoneAuthPassword
crudini --set /var/lib/config-data/merged/cinder.conf nova password $NovaKeystoneAuthPassword
# TODO: service token
#crudini --set /var/lib/config-data/merged/cinder.conf service_user password $CinderKeystoneAuthPassword
