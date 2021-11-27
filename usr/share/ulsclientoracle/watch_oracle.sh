#!/usr/bin/env bash
#
# watch_oracle.sh 
#
# ---------------------------------------------------------
# Copyright 2016 - 2021, roveda
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
#   watch_oracle.sh  <environment_script>  <configuration_file>
#
# ---------------------------------------------------------
# Description:
#   This script starts the watch_oracle.pl by invoking perl 
#   and passes through any additional arguments to it.
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
#   Renamed to watch_oracle.sh
#
# 2018-02-14      roveda      0.03
#   Changed all checks for successful sourcing the environment to
#   -z "$ORACLE_SID"
#   instead of
#   $? -ne 0 (what does not work)
#
# 2020-07-25      roveda      0.04
#   Changed the hash bang
#
# 2020-08-30      roveda      0.05
#   Added NLS_TIMESTAMP_FORMAT and NLS_TIMESTAMP_TZ_FORMAT.
#
# 2021-11-27      roveda      0.06
#   Changed default LANG setting from C to en_US.UTF-8
#
#
# ===================================================================


USAGE="watch_oracle.sh  <environment_script>  <configuration_file>"

unset LC_ALL
# export LANG=C
export LANG=en_US.UTF-8

cd `dirname $0`

# -----
# Check number of arguments

if [[ $# -ne 2 ]] ; then
  echo "$USAGE"
  exit 1
fi

# -----
# Set environment

ORAENV="$1"

if [[ ! -f "$ORAENV" ]] ; then
  echo "Error: environment script '$ORAENV' not found => aborting script"
  exit 2
fi

. "$ORAENV"

if [[ -z "$ORACLE_SID" ]] ; then
  echo 
  echo "Error: the Oracle environment is not set up correctly => aborting script"
  exit 2
fi

# -----
# Check for configuration file

CONFG="$2"

if [[ ! -f "$CONFG" ]] ; then
  echo
  echo "Error: standard configuration file '$CONFG' not found => aborting script"
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

perl test_before_run.pl "$CONFG" > /dev/null 2>&1 || exit


# -----
# Call the script.

# Set for decimal point, english messages and ISO date representation
# (for this client connection only).
# export NLS_LANG=AMERICAN_AMERICA.WE8ISO8859P1
export NLS_LANG=AMERICAN_AMERICA.UTF8
export NLS_DATE_FORMAT="YYYY-MM-DD hh24:mi:ss"
export NLS_TIMESTAMP_FORMAT="YYYY-MM-DD HH24:MI:SS"
export NLS_TIMESTAMP_TZ_FORMAT="YYYY-MM-DD HH24:MI:SS TZH:TZM"

perl watch_oracle.pl "$CONFG"

