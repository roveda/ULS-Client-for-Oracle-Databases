#!/usr/bin/env bash
#
# test_for_cdb.sh
#
# ---------------------------------------------------------
# Copyright 2020-2021, roveda
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
# 2021-11-27      roveda      0.02
#   Changed default LANG setting from C to en_US.UTF-8
#
# 2021-12-02      roveda      0.03
#   Added echoerr() and its usage
#   Get current directory thru 'readlink'.
#
# ===================================================================

# -----
# Function to echo to stderr
echoerr() { printf "%s\n" "$*" >&2; }

# -----
USAGE="test_for_cdb.sh  <environment_script> "

unset LC_ALL
# export LANG=C
export LANG=en_US.UTF-8

mydir=$(dirname "$(readlink -f "$0")")
cd "$mydir"

# -----
# Check number of arguments

if [[ $# -ne 1 ]] ; then
  echoerr "ERROR: You must specify the script to set the Oracle environment."
  echoerr "$USAGE"
  exit 1
fi

# -----
# Set environment

ORAENV="$1"

if [[ ! -f "$ORAENV" ]] ; then
  echoerr "Error: environment script '$ORAENV' not found => aborting script"
  exit 2
fi

. "$ORAENV"

if [[ -z "$ORACLE_SID" ]] ; then
  echoerr "Error: the Oracle environment is not set up correctly => aborting script"
  exit 2
fi


# -----

is_cdb=$(sqlplus -s -l -R 3 / as sysdba <<EOF
  set echo off heading off feedback off
  select cdb from v\$database;
EOF
)

# YES/NO

if [[ "$is_cdb" != "YES" ]] ; then
  # NO it is not a CDB
  exit 1
fi

# YES it is a CDB
exit 0

