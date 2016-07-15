#!/usr/bin/perl
#
# test_before_run.pl - Test, if any 'ULS Client for Oracle' script is to be run or not
#
# ---------------------------------------------------------
# Copyright 2013, roveda
#
# This file is part of 'ULS Client for Oracle'.
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
#   perl test_before_run.pl <configuration file>
#
# ---------------------------------------------------------
# Description:
#   This script reads the <configuration file> and gets the 
#   command defined in TEST_BEFORE_RUN. The script executes the 
#   command on system level and returns 0 if it was successful 
#   or it returns 1 if it was not successful.
#
#   It can be used to find out if any script of the 'ULS Client for Oracle'
#   shall be executed or not. The test may e.g. be a test if a 
#   specific directory is mounted or a process is running.
#
#   Send any hints, wishes or bug reports to: 
#     roveda at universal-logging-system.org
#
# ---------------------------------------------------------
# Options:
#   See the configuration file.
#
# ---------------------------------------------------------
# Restrictions:
#
# ---------------------------------------------------------
# Dependencies:
#   Misc.pm
#
# ---------------------------------------------------------
# Disclaimer:
#   The script has been tested and appears to work as intended,
#   but there is no guarantee that it behaves as YOU expect.
#   You should always run new scripts on a test instance initially.
#
# ---------------------------------------------------------
# Versions:
#
# "@(#) test_before_run.pl   0.01   2013-08-18   roveda"
#       Creation.
# "@(#) test_before_run.pl   0.02   2013-08-24   roveda"
#       Support no command as no tests necessary, exit(0)
# "@(#) test_before_run.pl   0.03   2016-03-18   roveda"
#       Added support for oracle_tools_SID.conf
#       (This is a preparation for fully automatic updates of the oracle_tools)
# "@(#) test_before_run.pl   0.04   2016-03-18   roveda"
#       Changed the non-default configuration filename to <sid>.conf
#
#
#        Change also $VERSION later in this script!
#
# ===================================================================


use strict;
use warnings;
use File::Basename;

# These are my modules:
use lib ".";
use Misc 0.36;

my $VERSION = 0.04;

# ===================================================================
# The "global" variables
# ===================================================================

# Name of this script.
my $CURRPROG = "";

# This keeps the contents of the configuration file
my %CFG;

# ===================================================================
# main
# ===================================================================
#
# -------------------------------------------------------------------
# Get configuration file contents

my $cfgfile = $ARGV[0];
# print "configuration file=$cfgfile\n";

my @Sections = ( "GENERAL" );
# print "Reading sections: ", join(",", @Sections), " from configuration file\n";

if (! get_config2($cfgfile, \%CFG, @Sections)) {
  print STDERR "$CURRPROG: Error: Cannot parse configuration file '$cfgfile' correctly => aborting\n";
  exit(1);
}

# Check for SID-specific .conf file
my ($name,$dir,$ext) = fileparse($cfgfile,'\..*');
# $cfgfile = "${dir}${name}_$ENV{ORACLE_SID}${ext}";
$cfgfile = "${dir}$ENV{ORACLE_SID}${ext}";

if (-r $cfgfile) {
  # print "$CURRPROG: Info: ORACLE_SID-specific configuration file '$cfgfile' found => processing it.\n";

  if (! get_config2($cfgfile, \%CFG, @Sections)) {
    print STDERR "$CURRPROG: Error: Cannot parse ORACLE_SID-specific configuration file '$cfgfile' correctly => aborting\n";
    exit(1);
  }
# } else {
#   print "$CURRPROG: Info: ORACLE_SID-specific configuration file '$cfgfile' NOT found. Executing with defaults.\n";
}

# show_hash(\%CFG, "=");
# print "-----\n\n";

my $cmd = $CFG{"GENERAL.TEST_BEFORE_RUN"};
# print "cmd=[$cmd]\n";

if (! $cmd) {
  # Got no command, assume no tests are necessary.
  # print "Continue with script...\n";
  exit(0);
}

my $cmd_out = `$cmd`;
my $result = $?;
# print "result=$result\n";

if ($result != 0) {
  # print "Do not execute script!\n";
  exit(1);
}

# print "Continue with script...\n";
exit(0);


