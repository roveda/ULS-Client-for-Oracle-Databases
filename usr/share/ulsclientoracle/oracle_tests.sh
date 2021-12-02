#!/bin/bash
#
# oracle_tests.sh
#
# ---------------------------------------------------------
# Copyright 2016-2017, 2021 roveda
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
#   oracle_tests.sh  <script_to_execute>
#
# ---------------------------------------------------------
# Description:
#   Execute the <script_to_execute> for each environment 
#   found in directory /etc/uls/oracle/oracle_env.d
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
#   Environment scripts in /etc/uls/oracle/oracle_env.d
#   Standard configuration filt /etc/uls/oracle/standard.conf
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
# Versions:
#
# date            name        version
# ----------      ----------  -------
#
# 2016-07-03      roveda      0.01
#   Created
#
# 2017-01-09      roveda      0.02
#   Removed some parameters.
#
# 2021-12-02      roveda      0.03
#   Added echoerr() and its usage, changed identification of WDIR.
#
#
# ===================================================================

# -----
# Function to echo to stderr
echoerr() { printf "%s\n" "$*" >&2; }

# -----
USAGE="oracle_tests.sh  <script_to_execute>"

# WDIR="`dirname $0`"
WDIR=$(dirname "$(readlink -f "$0")")

# Name of script to execute
SCRIPT="$1"

# Standardconfiguration for uls-client-oracle
STDCONF="/etc/uls/oracle/standard.conf"

if [ ! -f "$STDCONF" ] ; then
  echoerr "ERROR: configuration file '$STDCONF' does not exist => aborting script"
  exit 1
fi

# -----
# Default directory containing the environment scripts (or links to) 
# of all installed Oracle database instances.
ORAENVDIR="/etc/uls/oracle/oracle_env.d"

if [[ -d "$ORAENVDIR" ]] ; then

  # For all environment scripts in the directory.
  for env_file in "$ORAENVDIR"/* ; do

    # Start the script in background for each environment script found.
    if [[ -r "$env_file" ]] ; then
      "$WDIR"/$SCRIPT "$env_file" "$STDCONF" &
    else
      echo "ERROR: environment script '$env_file' not found, script '$SCRIPT' for this environment skipped."
    fi

  done
else
  echoerr "ERROR: directory '$ORAENVDIR' does not exist or is not readable => aborting script"
  exit 2
fi

exit 0

