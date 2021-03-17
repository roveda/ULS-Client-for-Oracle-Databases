#!/usr/bin/env bash
#
# test_for_cdb.sh
#
# ---------------------------------------------------------
# Copyright 2020, roveda
#
# This file is part of the 'ULS Client for Oracle'.
#
# The 'ULS Client for Oracle' is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# The 'ULS Client for Oracle' is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the 'ULS Client for Oracle'.  If not, see <http://www.gnu.org/licenses/>.
#
#
# ---------------------------------------------------------
# Synopsis:
#   test_for_cdb.sh  <environment_script>
#
# ---------------------------------------------------------
# Description:
#   This script checks the given Oracle database instance
#   of the given environment if it is a cdb, if it has pdbs.
#
#   Send any hints, feature requests or bug reports to:
#     roveda at universal-logging-system.org
#
# ---------------------------------------------------------
# Options:
#
# ---------------------------------------------------------
# Dependencies:
#
# ---------------------------------------------------------
# Restrictions:
#
#   This script only works for Oracle 12+ database instances. 
#   There was no column 'cdb' in older versions of v$database.
#   The script does not check the version, so must disable its
#   execution for older versions in the appropriate crontab file.
#
# ---------------------------------------------------------
# Disclaimer:
#   The script has been tested and appears to work as intended,
#   but there is no guarantee that it behaves as YOU expect.
#   You should always run new scripts in a test environment initially.
#
# ---------------------------------------------------------
# Versions:
#
# date            name        version
# ----------      ----------  -------
#
# 2020-08-29      roveda      0.01
#   Created
#
#
# ===================================================================


USAGE="test_for_cdb.sh  <environment_script> "

unset LC_ALL
export LANG=C

cd `dirname $0`

# -----
# Check number of arguments

if [[ $# -ne 1 ]] ; then
  echo "ERROR: You must specify the script to set the Oracle environment." >&2
  echo "$USAGE"
  exit 1
fi

# -----
# Set environment

ORAENV="$1"

if [[ ! -f "$ORAENV" ]] ; then
  echo "Error: environment script '$ORAENV' not found => aborting script" >&2

  exit 2
fi

. "$ORAENV"

if [[ -z "$ORACLE_SID" ]] ; then
  echo
  echo "Error: the Oracle environment is not set up correctly => aborting script" >&2

  exit 2
fi


# -----

is_cdb=$(echo $(sqlplus -s -l / as sysdba <<EOF
  set echo off heading off feedback off
  select cdb from v\$database;
EOF
))

# YES/NO

if [[ "$is_cdb" != "YES" ]] ; then
  # NO it is not a CDB
  exit 1
fi

# YES it is a CDB
exit 0

