#!/bin/bash
#
# uls_settings.sh
#
# ---------------------------------------------------------
# Copyright 2017, roveda
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
#   uls_settings.sh  <environment_script>  <configuration_file>
#
# ---------------------------------------------------------
# Description:
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
# 2017-05-31      roveda      0.01
#   Created
#
#
# ===================================================================


USAGE="uls_settings.sh  <environment_script>  <configuration_file>"

unset LC_ALL
export LANG=C

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

if [ $? -ne 0 ] ; then
  echo 
  echo "Error: Cannot source environment script '$ORAENV' => aborting script"
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
# Call the script.

perl uls_settings.pl "$CONFG"

