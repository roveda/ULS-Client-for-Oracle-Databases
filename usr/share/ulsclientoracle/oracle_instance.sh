#!/bin/bash
#
# oracle_instance.sh 
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
#   oracle_instance.sh <script_name> <environment_script> <standard_conf_file>
#
# ---------------------------------------------------------
# Description:
#   This script starts the given <script_name> by invoking perl 
#   and passes through any additional arguments to that <script_name>.
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


USAGE="oracle_instance.sh <script_name> <environment_script> <standard_conf_file>"

unset LC_ALL
export LANG=C

cd `dirname $0`

# -----
# Check number of arguments

if [[ $# -ne 3 ]] ; then
  echo "$USAGE"
  exit 1
fi

# -----
# Set environment

if [[ ! -f "$2" ]]
 then
  echo "Error: environment script '$2' not found => abort"
  exit 2
fi

. "$2"

if [ $? -ne 0 ] ; then
  echo 
  echo "Error: Cannot source environment script '$2' => abort"
  exit 2
fi

# -----
# Check for standard conf file

if [[ ! -f "$3" ]] ; then
  echo
  echo "Error: standard configuration file '$3' not found => abort"
  exit 2
fi


# -----
# HOSTNAME is used, but normally not set in cronjobs

HOSTNAME=`uname -n`
export HOSTNAME

# Remember to include the directory where flush_test_values can
# be found ('/usr/bin' or '/usr/local/bin') in the PATH.


# -----
# Exit silently, if the TEST_BEFORE_RUN command does
# not return the exit value 0.

perl test_before_run.pl "$3" > /dev/null 2>&1 || exit


# -----
# Call the script.

# Set for decimal point, english messages and ISO date representation
# (for this client only).
# export NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P1
export NLS_LANG=AMERICAN_AMERICA.UTF8
export NLS_DATE_FORMAT="YYYY-MM-DD hh24:mi:ss"
# (although it did not worked as expected)

perl "$1" "$3"

