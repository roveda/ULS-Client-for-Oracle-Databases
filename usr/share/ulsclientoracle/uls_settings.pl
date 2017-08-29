#!/usr/bin/perl
#
# uls_settings.pl - print all effective ULS settings to stdout
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
# along with the 'ULS Client for Oracle'. If not, see <http://www.gnu.org/licenses/>.
#
#
# ---------------------------------------------------------
# Synopsis:
#   perl uls_settings.pl <configuration file>
#
# ---------------------------------------------------------
# Description:
#   This script parses the configuration file and processes all
#   ULS settings to their final effective settings and prints them out.
#     ULS_HOSTNAME=linux123
#     ULS_SECTION=Oracle DB[orcl]
#     ...
#   You may parse the output to extract needed values in other scripts.
#   The correct Oracle environment must be set. 
#
#   Send any hints, wishes or bug reports to: 
#     roveda at universal-logging-system.org
#
# ---------------------------------------------------------
# Options:
#
# ---------------------------------------------------------
# Dependencies:
#   Misc.pm
#   Uls2.pm
#   uls-client-2.0-1 or later
#   You must set the necessary Oracle environment variables
#   or configuration file variables before starting this script.
#
# ---------------------------------------------------------
# Restrictions:
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
#
# date            name        version
# ----------      ----------  -------
# 2017-05-31      roveda      0.01
#
#   Initial version
#
#   Change also $VERSION later in this script!
#
# ===================================================================


use 5.003_07;
use strict;
use warnings;
use File::Basename;


# These are my modules:
use lib ".";
use Misc 0.40;
use Uls2 1.15;

my $VERSION = 0.01;

# ===================================================================
# The "global" variables
# ===================================================================

my $CURRPROG;  # Keeps the name of this script.

# This keeps the configuration parameters
my %CFG;

# This keeps the settings for the ULS
my %ULS;


# ===================================================================
# The subroutines
# ===================================================================


# ------------------------------------------------------------
sub show_hash_special {
  #
  #   show_hash_special(<ref to hash> [, separator [, leading_expr]])
  #
  # Displays a hash with sorted keys and their values (if present).

  my $href = $_[0];    # Reference to given hash
  my $sep = $_[1] || " := ";
  my $leadexpr = $_[2] || "";

  my @ks = sort(keys(%$href));

  foreach my $k (@ks) {
    # $t = $$href{$k} || " ";   # don't do this, it will output a blank when a zero is expected!

    my $t = " ";
    if (defined($$href{$k})) {$t = $$href{$k}}

    # if ($t) {$t = " "}   # But there may be no value, so set it to blank just for showing

    # print "-----\n";
    print "$leadexpr" . uc($k) . "$sep$t\n";
  }
  # if(scalar(@ks)) {print "-" x 20, "\n"}
  # else {print "--- empty hash ---\n"}

} # show_hash_special




# ===================================================================
# main
# ===================================================================
#

$CURRPROG = basename($0, ".pl");
my $currdir = dirname($0);

# -------------------------------------------------------------------
# Get configuration file contents

my $cfgfile = $ARGV[0];
# print "configuration file=$cfgfile\n";

my @Sections = ("ULS");
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

# ----------
# This sets the %ULS to all necessary values
# deriving from %CFG (configuration file),
# environment variables (ULS_*) and defaults.

uls_settings(\%ULS, \%CFG);

show_hash_special(\%ULS, "=", "ULS_");

exit(0);

#########################
# end of script
#########################

__END__

# The format:
#
# *<teststep title>
# <any text>
# <any text>
#
# *<teststep title>
# <any text>
# <any text>
# ...
#
# Remember to keep the <teststep title> equal to those used
# in the script. If not, you won't get the expected documentation.
#
# Do not use the '\' but use '\\'!

