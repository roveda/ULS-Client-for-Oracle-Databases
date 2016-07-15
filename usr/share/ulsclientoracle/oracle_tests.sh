#!/bin/bash
#
# oracle_tests.sh
#
# ---------------------------------------------------------
# Copyright 2016, roveda
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
#   exec_script.sh <script_name> <environment_script> <standard_conf_file>
#
# ---------------------------------------------------------
# Description:
#   Execute watch_oracle.sh for each environment 
#   found in directory /etc/uls/oracle/oracle_env.d
#   (or another directory given as --oracle-env-dir argument).
#
#   Send any hints, wishes or bug reports to:
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
# ---------------------------------------------------------
# Disclaimer:
#   The script has been tested and appears to work as intended,
#   but there is no guarantee that it behaves as YOU expect.
#   You should always run new scripts in a test environment initially.
#
# ---------------------------------------------------------
# Changes:
#
# 2016-07-03, 0.01, roveda:
#   Created
#
#
#
# ===================================================================

USAGE="oracle_tests.sh  --script=<script_name> [--oracle-env-dir=<oracle_env_dir>] [--standard-conf=<path_to_stdconf>]"

WDIR="`dirname $0`"

# Name of script to execute
SCRIPT=""

# Standardconfiguration for uls-client-oracle
STDCONF="/etc/uls/oracle/standard.conf"

# -----
# Default directory containing the environment scripts (or links to) 
# of all installed Oracle database instances.
ORAENVDIR="/etc/uls/oracle/oracle_env.d"

# -----

while [[ $# -gt 0 ]] ; do
  case $1 in
    --script=*)
      SCRIPT="${1#*=}"
      ;;
    --oracle-env-dir=*)
      ORAENVDIR="${1#*=}"
      ;;
    --standard-conf=*)
      STDCONF="${1#*=}"
      ;;
  esac
  shift
done

# -----
if [[ -z "$SCRIPT" ]] ; then
  echo "$USAGE"
  exit 1
fi


if [[ -d "$ORAENVDIR" ]] ; then

  for env_file in "$ORAENVDIR"/* ; do

    if [[ -r "$env_file" ]] ; then
      #       exec_script.sh <script_name> <environment_script> <standard_conf_file>
      "$WDIR"/oracle_instance.sh "$SCRIPT" "$env_file" "$STDCONF" &
    fi

  done

fi


