#!/usr/bin/perl
#
# watch_oracle.pl - monitor a running Oracle database instance
#
# ---------------------------------------------------------
# Copyright 2004 - 2021, roveda
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
#   perl watch_oracle.pl <configuration file>
#
# ---------------------------------------------------------
# Description:
#   This script monitors an oracle instance and database.
#   You may optionally specify parameters in the configuration file 
#   to gather advanced metrics.
#
#   Send any hints, wishes or bug reports to: 
#     roveda at universal-logging-system.org
#
# ---------------------------------------------------------
# Options:
#   See the configuration file.
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
#   RAC specifics are currently not covered.
#
#   You should purge the recycle bin regularly if you use it!
#   An sql is used against dba_free_space which includes a 
#   query also against sys.recyclebin$ (since 10g).
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
# 2004-06-24      roveda      0.01
#
# 2004-06-31      roveda      0.02
#   Added 'buffer cache'
#   messages from script run.
#
# 2004-07-06      roveda      0.03
#   Added redo(). Sending message at once to ULS when errors arise
#   using output_error_message().
#
# 2004-07-15     roveda      0.04
#   Added $VERSION.
#
# 2004-07-22      roveda      0.05
#   Added LOCK file checking. This script checks if a lock file exists
#   and aborts silently.
#
# 2004-07-28      roveda      0.06
#   Re-activated 'overallocation count' in pga(),
#   Sending the hostname along (interesting for clusters).
#
# 2004-08-19      roveda      0.07
#   Test status of redo log member files.
#   Now putting my own process id into LOCK file. Next running
#   instance checks if according process is still running, deleting
#   the LOCK file if not.
#
# 2004-08-20      roveda      0.08
#   Sending the documentation in each sub now, using a prepared
#   hash to keep the texts. Lockfile moved to misc_lib.pm
#   'active transactions' and 'number of extents' are only snapshots,
#   not summarized.
#
# 2004-10-13      roveda      0.09
#   tablespace_info() changed. library_cache() changed.
#   Documentation added.
#
# 2004-11-01      roveda      0.10
#   "total bytes processed" debugged in pga().
#   "redo size" in redo_logs() is now calculated as difference to last run.
#
# 2004-12-09      roveda      0.11
#   Moved to "start-stop", IDENTIFIER, "script name, version" and
#   uses now send_runtime(). Obsolete variables removed.
#
# 2005-01-13      roveda      0.12
#   Documentation to tablespace_info now sent for each tablespace, it
#   was not accessible until then.
#
# 2005-02-28      roveda      0.13
#   Added "buffer cache/used".
#
# 2005-03-09      roveda      0.14
#   Changed buffer_cache() for Oracle 10g.
#   Added some docs for "system statistics".
#
# 2005-03-30      roveda      0.15
#   Scanning of alert.log now only uses complete lines (terminated with '\n').
#   That should fix the problems with concurrent writing and reading.
#
# 2005-04-07      roveda      0.16
#   New script name, buffer cache hit ratio has other formula
#   for 10g. Changed to simpler sql statement for tablespace
#   usage.
#
# 2005-04-20      roveda      0.17
#   Added 'database available' (0% / 100%) to 'Info'.
#
# 2005-05-10      roveda      0.18
#   Removed the "backslash" print out in alert_log()
#
# 2005-08-01      roveda      0.19
#   Now uses Misc.pm and Uls.pm, returns the exit code to the
#   calling context.
#
# 2005-08-16      roveda      0.20
#   Added some SETs to exec_sql(). Remove LOCK file at the very end
#   of the script. Specific wait events are sent to the ULS.
#
# 2005-09-20      roveda      0.21
#   Calculation of free temp tablespace corrected.
#   Real script name is sent to ULS.
#
# 2005-11-25      roveda      0.22
#   Using now scheduled() instead of elapsed().
#   Added parameters(), added objects_in_buffer_cache().
#   Accepts now BUFFER_OBJECTS as parameter, then generates
#   a buffer statistic about its objects.
#
# 2005-12-01      roveda      0.23
#   Added "consistent gets" to system_statistics(), added documentation.
#
# 2006-01-31      roveda      0.24
#   Added "maximum PGA allocated" to pga(). Buffer cache hit ratio is now
#   limited to [0.0 .. 100.0]. wait_events() overview removed.
#   Added latch()
#
# 2006-02-07      roveda      0.25
#   The sqlplus command is now enclosed in " (double quotes) instead
#   of ' (single quote). This was necessary for running on Wind*ws.
#   Do not use "n/a" if a value cannot be determined, do not send anything
#   (a mix of data types irritates the graphics module). Messages in the
#   alertSID.log are now sent for detail "entry".
#
# 2006-04-25      roveda      0.26
#   Added recalc() especially for "redo size", which wraps at 4294967296 (4G)
#   and starts again at zero. The previously negative values are now
#   calculated correctly. wait_events() now gets all appearing events,
#   but WAIT_EVENTS must be specified as parameter when starting the script.
#   Library cache values are only sent if one value differs from zero.
#   Skipped several not so interesting values in sga()
#
# 2006-06-09      roveda      0.27
#   Using long strings now in send_parameters().
#
# 2006-06-26      roveda      0.28
#   Use the "sum of size of all user objects" as used space of
#   temporary tablespaces (the used space is only returned on demand (lazy).
#
# 2006-09-07      roveda      0.29
#   "written to rollback segment" now wraps numerically correct at 4G.
#   tablespace_usage()-used was wrong, when no objects exist in a tablespace.
#
# 2006-09-20      roveda      0.30
#   Now supports correct values for buffer caches when using
#   use_indirect_data_buffers (1GB more for 32bit linux).
#
# 2006-09-25      roveda      0.31
#   Added 'execute count' and 'parse count (total)' to system_statistics().
#   Changed several sprintf() to the new function pround() and needs
#   therefore the latest Misc.pm version (and the latest Uls.pm).
#
# 2007-03-07      roveda      0.32
#   Checking tablespaces for "is autoextensible". Corrected "free" for
#   "tablespace usage". Added "open cursors" and "session cached cursors".
#   Check alert.log also for expression "Errors in file...", which
#   sometimes does not generate an ORA- message.
#
# 2007-03-07      roveda      0.33
#   Number of autoextensible temp files was always zero, corrected.
#
# 2007-05-22      roveda      0.34
#   Do not send values to the ULS if work files have been freshly
#   built or the first run after a database bounce. Write temporary
#   and work files to directory specified in ULS_VAR_DIR or to
#   current directory if ULS_VAR_DIR is not specified. You may
#   specify a --configuration-file as parameter. You may specify
#   SQLPLUS_COMMAND in the configuration file, if it is not the
#   default 'sqlplus "/ as sysdba"' that works (mostly on Wind*ws).
#
# 2007-06-15      roveda      0.35
#   Added jobs() (see OPTIONS = ...JOBS in the configuration file).
#   Zeroed the rightmost second of the ULS timestamp. Added support
#   for HTTPS environment settings.
#
# 2007-09-11      roveda      0.36
#   This script now needs! a configuration file, which must be
#   the first command line parameter. It needs also the latest
#   versions of Misc.pm (0.22) and Uls.pm (0.21).
#
# 2008-09-17      roveda      0.37
#   IDENTIFIER is now used in WORKFILEPREFIX. That allows several
#   separate watch_oracle scripts per instance.
#
# 2009-01-30      roveda      0.38
#   Changed to Uls2.pm and usage with ULS-Server 1.5.3 and uls-client-2.0-1.
#   Added support for Oracle 11. Number of redo log switches,
#   components, scheduler.
#
# 2009-02-17      roveda      0.39
#   alert.log for Oracle 11 from v$diag_info. Buffer cache hit ratio
#   is equal to Oracle 10.
#
# 2009-03-19      roveda      0.40
#   Added the number of (not only auto-extensible) datafiles per tablespace.
#   Added doc to library cache. Excerpt of trace file is send in conjunction
#   with "Errors in file ...". NLS_DATABASE_SETTINGS are sent once a day.
#   <file>.nineoclock replaces <file>.last_doc_sent and <file>.last_parameters.
#
# 2009-06-15      roveda      0.41
#   "set linesize 5000" in sub exec_sql(), because at least v$parameter has
#   value of 4000 lemgth.
#
# 2009-12-29      roveda      0.42
#   Now removing old temporary log files correctly. Added flashback partially.
#   "objects" in "buffer cache" are now shown in MB. Leaving out 'other' wait class.
#   Added excerpt of Oracle doc for several wait events. Omitted the
#   "Info -- database available". Some values are only sent every DEFAULT_ELAPSED,
#   if the value is equal to the previous value.
#
# 2010-02-18      roveda      0.43
#   Changed "jobs" to a newmore verbose output.
#
# 2010-02-25      roveda      0.44
#   Debugged get_objects_in_buffer() for databases with partitioning.
#
# 2010-03-08      roveda      0.45
#   rollback_segment_summary() is to be activated optionally, now
#   undo_usage() has been implemented instead (work in progress).
#   Added banner output to general_info() to show what Oracle version is in use.
#   Added "corrupt block" as search expression for alert.log
#   (got that 2010-03-31, no ORA-, though)
#
# 2010-09-27      roveda      0.46
#   Removed obsolete "Ok" and 0 values sent to the ULS-server before
#   "instant limit definition on incoming values" was implemented.
#   The limits on the ULS-server must be changed! See "ULS-0018DE-03W ORACLE_TOOLS".
#
# 2010-12-30      roveda      0.47
#   Removed tablespace_info(), parameters(), nls_settings(), components(),
#   banner output, because these information are gathered when running
#   script ora_dbinfo_xxx.
#
# 2011-03-03      roveda      0.49
#   Debugged a division by zero in wait_event_classes(),
#   Debugged the determination of alert.log's directory for Oracle 11.
#
# 2011-11-11      roveda      0.50
#   Added GPL license.
#
# 2011-12-21      roveda      0.51
#   Added scheduler_details(). ORACLE_MAJOR_VERSION and ORACLE_MINOR_VERSION
#   are available throughout the script as integers. That allows easy check
#   for version specific distinction.
#
# 2012-04-27      roveda      0.52
#   Added cpu used to scheduler job details.
#
# 2013-02-10      roveda      0.53
#   Disabled the BUFFER_OBJECTS option, because of incorrect sql.
#   Added the number of failed logins if audit_trail is set.
#
# 2013-08-10      roveda      0.54
#   Changed the linesize from 10000 to 32000, v$parameter seem to
#   contain longer lines, the appropriate results were missing.
#
# 2013-08-17      roveda      0.55
#   Modifications to match the new single configuration file.
#
# 2014-02-02      roveda      0.56
#   Changed several sql statements to use bind variables instead of
#   dynamically produced expressions which require hard parsing.
#   Simplified the determination of the tablespace usage in tablespace_usage().
#
# 2014-02-03      roveda      0.57
#   Changed some more sql statements to use bind variables.
#   Debugged wrong sql statement in audit_information()
#
# 2014-08-10      roveda      0.58
#   Changed some more sql commands to use bind variables.
#   Switched the columns in the failed login report.
#
# 2014-11-11      roveda      0.59
#   Sending "max processes" before other process and session related values.
#   That avoids notifications for the first run of this script.
#   All backslashes are converted to dots in sub audit_information().
#   Made the options global (OPTIONS) to use it in subs.
#   Teststep documentation is now found correctly, titles are converted to lowercase.
#   Added missing documentation sections, removed outdated.
#
# 2015-02-14      roveda      0.60
#   Debugged a wrong number of array elements in scheduler_details().
#   Added "exit value" as final numerical result (0 = "OK"),
#   in contrast to "message" which is the final result as text.
#   That allows numerical combined limits like:
#   notify, if two of the last three executions have failed.
#   Debugged scheduler_details(): scheduled jobs running longer than the execution
#   cycle of this script were omitted/not recognized.
#
# 2015-05-05      roveda      0.61
#   Added NVL() to some select commands.
#
# 2015-09-16      roveda      0.62
#   Added the successful logins in audit_information().
#
# 2015-09-24      roveda      0.63
#   Re-worked the sql command for successful and failed logins.
#
# 2015-12-13      roveda      0.64
#   Changed some units from ' ' to '[ ]'.
#   Info about flashback is only sent if activated.
#   Infos about detailed library cache only on demand.
#   Infos about wait event classes only on demand.
#   Start-Stop omitted.
#
# 2016-02-04      roveda      0.65
#   Some values only once a day, changed nine_o_clock to ONCE_A_DAY.
#
# 2016-02-24      roveda      0.66
#   Added TNSPING as check.
#   The "exit value" is no longer sent to ULS.
#
# 2016-03-17      roveda      0.67
#   If any value for general_info() changes, send all values.
#   Added support for oracle_tools_SID.conf
#   (This is a preparation for fully automatic updates of the oracle_tools)
#
# 2016-03-23      roveda      0.68
#   Added the SID to the WORKFILEPREFIX.
#
# 2016-05-31      roveda      0.69
#   Changed from MB to GB for tablespace sizes and usage.
#   Added the theoretical maxsize of a tablespace.
#
# 2016-07-03      roveda      0.70
#   Changed the non-default configuration filename to <sid>.conf
#
# 2016-12-19      roveda      0.71
#   Corrected the documentation lookup expression for "Session Cached Cursors"
#
# 2017-02-09      roveda      0.72
#   Added schema_information() as new feature.
#
# 2017-02-16      roveda      0.73
#   Removed 'last execution before' in jobs(), it is useless.
#   Added 'administrative database user' as new teststep. 
#   Count and list is sent once a day.
#
# 2017-02-24      roveda      0.74
#   In case of an unknown state of the database, the following execution of 
#   the script did not deliver the correct values for the "Info" details, 
#   it was not saved to the workfile. Now, undefined values are written to 
#   the workfile if the sql commands could not be executed or the database 
#   is not available.
#
# 2017-05-26      roveda      0.75
#   Added admin_db_user(), which generates a list of non-oracle user with adminstrative privileges.
#
# 2017-06-21      roveda      0.76
#   Handling of lowercase tablespace names corrected.
#
# 2017-08-15      roveda      0.77
#   Debugged the sql for the list of non-oracle user with adminstrative privileges.
#   Added 'potential max size' to tablespace information. That is the maximum size
#   a tablespace can grow to, depending on the settings of its data (or temp) files.
#
# 2017-09-25      roveda      0.78
#   Added $ORACLE_VERSION_3D for exact version comparisons.
#   Column DELEGATE_OPTION does not exist in Oracle versions lower than 12.1.0.2, 
#   COMMON not in versions lower than 12.1.0.1. So admin_db_user() is skipped for 
#   all Oracle versions lower than 12.1.0.2.
#
# 2017-12-20      roveda      0.79
#   Changed the meaning of details in tablespace usage. 
#   %used is now calculated in relation to potential max size.
#
# 2018-01-19      roveda      0.80
#   Added 'parse count (hard)', 'transaction rollbacks' and 'user rollbacks' to system statistics.
#   Updated the versions of the used perl modules.
#   %used for tablespaces is renamed to %used_pms (of potential max size).
#   A correct error message is given if the alert.log could not be found
#   (and not '-not found-').
#
# 2018-03-12      roveda      0.81
#   Added monitoring of failed logins also for unified auditing.
#
# 2018-10-03      roveda      0.82
#   Removed a calculation of values that are no longer acquired in sga().
#
# 2019-07-06      roveda      0.83
#   Added support for physical standby databases in Dataguard environments.
#   Tablespace data and audit data are currently omitted for physical standby.
#
# 2019-07-13      roveda      0.84
#   Bail out from sub if status is not OPEN and DBA_ views are referenced.
#
# 2019-09-19      roveda      0.85
#   Added 'max processes since startup' derived from v$pgastat.
#
# 2019-09-30      roveda      0.86
#   Added dataguard()
#
# 2019-10-15      roveda      0.87
#   Added execution information about the auto optimizer stats collection job
#   in auto_optimizer_stats_collection().
#
# 2019-10-22      roveda      0.88
#   Added the maintenance window information to auto optimizer stats collection
#   jobs in auto_optimizer_stats_collection().
#
# 2019-11-27      roveda      0.89
#   Debugged comparisons and the parent db_unique_name in dataguard()
#
# 2020-02-04      roveda      0.90
#   Added blocking_sessions()
#
# 2020-03-05      roveda      0.91
#   Added special filter for alert.log entries witch contain ORA- expressions, 
#   but as patch description and not as real error entry.
#   Detect timestamps in the alert.log, use it for output.
#
#   The job_info in auto_optimizer_stats_collection() may contain a 'ORA-'
#   expression, that leads to an error message and the script fails generally.
#   Therefore, all 'ORA-' expressions in job_info are replaced by 'ORA - '.
#
# 2020-08-01      roveda      0.92
#   Added the full Oracle version for 18 and later.
#
# 2020-09-01      roveda      0.93
#   Use now correct timestamp for 'auto optimizer stats collection'.
#   Removed 'DBWR checkpoint buffers written' from system statistics.
#
# 2020-09-07      roveda      0.94
#   Added 'compatible' to teststep 'info'.
#   Optimized the sql for some values in general().
#
# 2020-09-30      roveda      0.95
#   Integrated the PDB tests (now all in this script).
#
# 2020-11-26      roveda      0.96
#   Added smooth transition to new workfile for alert_log().
#
# 2021-01-18      roveda      0.97
#   Current size aof SGA ist now only sent to ULS if it has changed or just once a day.
#
# 2021-02-05      roveda      0.98
#   Added the number of INACTIVE online redo logs in redo_logs().
#   Added GROUPED_CONNECTIONS. Removed [WATCH_ORACLE_PDBS] from configuration file.
#
# 2021-03-17      roveda      1.00
#   Changed 'blocking sessions' to deliver the final blocking session as simple expression
#   and not as text report file.
#
#
#   Change also $VERSION later in this script!
#
# ===================================================================


use 5.003_07;
use strict;
use warnings;
use File::Basename;
use File::Copy;
use Config::IniFiles;
use Time::Local;

# These are my modules:
use lib ".";
use Misc 0.43;
use Uls2 1.16;

my $VERSION = 1.00;

# ===================================================================
# The "global" variables
# ===================================================================

my $CURRPROG;  # Keeps the name of this script.

# The default command to execute sql commands.
my $SQLPLUS_COMMAND = 'sqlplus -S "/ as sysdba"';

my $WORKFILE = Config::IniFiles->new();
my $WORKFILEPREFIX;
my $TMPOUT1;
my $LOCKFILE;
my $FAILED_LOGIN_REPORT;
my $ADMIN_DBUSER_REPORT;

my $DELIM = "!";

# This hash keeps the command line arguments
my %CMDARGS;

# This keeps the configuration parameters
my %CFG;

# This keeps the settings for the ULS
my %ULS;

# The options defined in the configuration file
my $OPTIONS;

# That is used to give the workfiles a timestamp.
# If it has changed since the last run of this script, it
# will build new workfiles (e.g. when the system is rebooted).
# (similar to LAST_ONSTAT_Z for Informix)
my $WORKFILE_TIMESTAMP = "";

# Some helping constants for calculating {K | M | G}Bytes (you must divide):
my $KB = 1024;
my $MB = $KB * $KB;
my $GB = $KB * $MB;

my $MB_FMT  = "%.1f";  # sprintf formatting for MegaBytes
my $PC_FMT  = "%.1f";  # sprintf formatting for %
my $SEC_FMT = "%.3f";  # sprintf formatting for seconds

# This is to indicate "not available":
my $NA = "n/a";

# Use this to test for (nearly) zero:
my $VERY_SMALL = 1E-60;

# Default elapsed time between values, if their value has not changed.
# Mostly used for status values.
my $DEFAULT_ELAPSED = "01:45";

# The $MSG will contain still the "OK", when reaching the end
# of the script. If any errors occur (which the script is testing for)
# the $MSG will contain "ERROR" or a complete error message, additionally,
# the script will send any error messages to the uls directly.
# <hostname> - "Oracle Database Server [xxxx]" - __watch_oracle9.pl - message
my $MSG = "OK";

# Final numerical value, 0 if MSG = "OK", 1 if MSG contains any other value
my $EXIT_VALUE = 0;

# Is set to 1, if values of only daily interest are sent.
# These values are not sent during the other executions.

my $ONCE_A_DAY = 0; 

# This hash keeps the documentation for the teststeps.
my %TESTSTEP_DOC;

# Holds the __$CURRPROG or $CFG{"IDENTIFIER"} just for easy usage.
my $IDENTIFIER;

# Keeps the version of the oracle software
my $ORACLE_VERSION = "";
# Starting with Oracle 18, you can derive the full Oracle version.
# For all older versions, this will be the same as ORACLE_VERSION.
my $ORACLE_VERSION_FULL = "";

my $ORACLE_VERSION_3D = "";
my $ORACLE_MAJOR_VERSION = "";
my $ORACLE_MINOR_VERSION = "";

# -----
# The following two variables indicate a 'normal' instance
# OPEN / PRIMARY
# or a standby Dataguard instance.
# MOUNTED / PHYSICAL STANDBY
# -----
# SELECT STATUS FROM V$INSTANCE;
# { OPEN | MOUNTED }
my $ORACLE_STATUS = "";

# -----
# SELECT DATABASE_ROLE FROM V$DATABASE;
# { PRIMARY | PHYSICAL STANDBY }
my $ORACLE_DBROLE = "";


# Data Guard Role
my $DG_ROLE = "NONE";

# Keeps the list of all present pdbs (for the current cdb)
my @PDB_LIST = ();

# Holds the current pdb name (of @PDB_LIST)
my $CURRENT_PDB = "";
my $CURRENT_CON_ID = -1;

# Status of the current PDB
my $PDB_STATUS = "";



# ===================================================================
# The subroutines
# ===================================================================


# ------------------------------------------------------------
sub set_value {
  # set_value(\$workfile, <section>, <parameter>, <value>);
  # set_value(\$WORKFILE, "GENERAL", "LAST_RUN", iso_datetime($start_secs));

  # Set a value for a parameter in a section of a pointer to a workfile
  # that has the structure of an ini-file.
  # See:
  #   my $WORKFILE = Config::IniFiles->new();

  my ($rCFG, $section, $parameter, $value) = @_;

  my $ret = undef;

  $$rCFG->AddSection($section);

  if( $$rCFG->val($section, $parameter) ) {
    $ret = $$rCFG->val($section, $parameter);
    $$rCFG->setval($section, $parameter, $value );
  } else {
    $$rCFG->newval($section, $parameter, $value );
  }

  # print "section=$section, parameter=$parameter, value=$value\n";

  return($ret);

} # set_value


# ------------------------------------------------------------
sub output_error_message {
  # output_error_message(<message>)
  #
  # Send the given message(s), set the $MSG variable and
  # print out the message.

  $EXIT_VALUE = 1;
  $MSG = "ERROR";
  foreach my $msg (@_) { print STDERR "$msg\n" }
  foreach my $msg (@_) { uls_value($IDENTIFIER, "message", $msg, " ") }

} # output_error_message


# ------------------------------------------------------------
sub errors_in_file {
  # errors_in_file <filename>
  #
  # Check contents of e.g. $TMPOUT1 for ORA- errors.

  my $filename = $_[0];

  if (! open(INFILE, "<$filename")) {
    output_error_message(sub_name() . ": Error: Cannot open '$filename' for reading. $!");
    return(1);
  }

  my $L;

  while ($L = <INFILE>) {
    chomp($L);
    if ($L =~ /ORA-/i) {
      # yes, there have been errors.
      output_error_message(sub_name() . ": Error: There have been error(s) in file '$filename'!");
      return(1);
    }

  } # while

  if (! close(INFILE)) {
    output_error_message(sub_name() . ": Error: Cannot close file handler for file '$filename'. $!");
    return(1);
  }
  return(0); # everything ok
} # errors_in_file


# ------------------------------------------------------------
sub reformat_spool_file {
  # reformat_spool_file(<filename>)
  #
  # Reformats the spool file, removes unnecessary blanks surrounding
  # the delimiter, like this:
  #
  # ARTUS                         !          2097152000!            519569408
  # SYSTEM                        !          2097152000!            174129152
  # UNDOTS                        !          1048576000!             10027008
  #
  # ARTUS!2097152000!519569408
  # SYSTEM!2097152000!174129152
  # UNDOTS!1048576000!10027008
  #
  # This is necessary, because matching of constant expressions (like 'ARTUS')
  # would fail (the proper expression would be: 'ARTUS                         ').

  my $filename = $_[0];
  my $tmp_filename = "$filename.tmp";

  if (! open(INFILE, $filename)) {
    output_error_message(sub_name() . ": Error: Cannot open '$filename' for reading. $!");
    return(0);
  }

  if (! open(OUTFILE, ">$tmp_filename")) {
    output_error_message(sub_name() . ": Error: Cannot open '$tmp_filename' for writing. $!");
    return(0);
  }

  my $L;

  while($L = <INFILE>) {
    chomp($L);
    my @e = split($DELIM, $L);
    my $E;
    foreach $E(@e) {
      print OUTFILE trim($E), $DELIM;
    }
    print OUTFILE "\n";
  }

  if (! close(INFILE)) {
    output_error_message(sub_name() . ": Error: Cannot close file handler for file '$filename'. $!");
    return(0);
  }

  if (! close(OUTFILE)) {
    output_error_message(sub_name() . ": Error: Cannot close file handler for file '$tmp_filename'. $!");
    return(0);
  }

  if (! copy($tmp_filename, $filename)) {
    output_error_message(sub_name() . ": Error: Cannot copy '$tmp_filename' to '$filename'. $!");
    return(0);
  }

  if (! unlink($tmp_filename)) {
    output_error_message(sub_name() . ": Error: Cannot remove '$tmp_filename'. $!");
    return(0);
  }
} # reformat_spool_file


# ------------------------------------------------------------
sub write2file {
  # write2file(<file>, <expression>);
  #
  # write an expression to a file
  # The file is created, the expression is written into, then the file is closed.
  # That may not be the best performance for your general needs.

  my ($filename, $txt) = @_;

  if (! open(OUTFILE, ">", $filename)) {
    output_error_message(sub_name() . ": Error: Cannot open '$filename' for writing. $!");
    return(0);
  }

  # Remember to insert the \n in the expression if needed!
  print OUTFILE $txt;

  if (! close(OUTFILE)) {
    output_error_message(sub_name() . ": Error: Cannot close file handler for file '$filename'. $!");
    return(0);
  }

  return(1);

} # write2file


# ------------------------------------------------------------
sub exec_sql {
  # <sql command>
  # Just executes the given sql statement against the current database instance.
  # If <verbose> is a true expression (e.g. a 1) the sql statement will
  # be printed to stdout.

  # connect / as sysdba

  # Set nls_territory='AMERICA' explicitly to get decimal points.

  my $set_container = "";
  # For PDBs
  if ( $CURRENT_PDB ) {
    print "CURRENT_PDB=$CURRENT_PDB\n";
    $set_container = "alter session set container=$CURRENT_PDB;";
  }


  my $sql = "
    set echo off

    alter session set nls_territory='AMERICA';
    alter session set NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS';
    alter session set NLS_TIMESTAMP_FORMAT='YYYY-MM-DD HH24:MI:SS';
    alter session set NLS_TIMESTAMP_TZ_FORMAT='YYYY-MM-DD HH24:MI:SS TZH:TZM';

    $set_container
    set newpage 0
    set space 0
    set linesize 32000
    set pagesize 0
    set feedback off
    set heading off
    set markup html off spool off

    set trimout on;
    set trimspool on;
    set serveroutput off;
    set define off;
    set flush off;

    set numwidth 20
    set colsep '$DELIM'

    spool $TMPOUT1;

    $_[0]

    spool off;";

  print "\n" . sub_name() . ": Info: executed SQL command:\n";
  print "SQL: $sql\n-----\n";

  # -----
  my $t0 = time;

  if (! open(CMDOUT, "| $SQLPLUS_COMMAND")) {
    print sub_name() . ": Info: execution time:", time - $t0, "s\n";
    output_error_message(sub_name() . ": Error: Cannot open pipe to '$SQLPLUS_COMMAND'. $!");
    return(0);   # error
  }

  print CMDOUT "$sql\n";
  if (! close(CMDOUT)) {
    print sub_name() . ": Info: execution time:", time - $t0, "s\n";
    output_error_message(sub_name() . ": Error: Cannot close pipe to sqlplus. $!");
    return(0);
  }

  print sub_name() . ": Info: execution time:", time - $t0, "s\n";

  # -----
  $t0 = time;

  reformat_spool_file($TMPOUT1);

  print sub_name() . ": Info: result formatting time:", time - $t0, "s\n";

  # -----
  return(1);   # ok
} # exec_sql


# -------------------------------------------------------------------
sub do_sql {
  # do_sql(<sql>)
  #
  # Returns 0, when errors have occurred,
  # and outputs an error message,
  # returns 1, when no errors have occurred.

  if (exec_sql($_[0])) {
    if (errors_in_file($TMPOUT1)) {
      output_error_message(sub_name() . ": Error: there have been errors when executing the sql statement.");
      uls_send_file_contents($IDENTIFIER, "message", $TMPOUT1);
      return(0);
    }
    # Ok
    return(1);
  }

  output_error_message(sub_name() . ": Error: Cannot execute sql statement.");
  uls_send_file_contents($IDENTIFIER, "message", $TMPOUT1);

  return(0);

} # do_sql


# -------------------------------------------------------------------
sub recalc {
  # recalc(<wrap at>, <previous file>, <current file>, <delimiter>, <first col expression> [, <column>])
  # recalc(4, $workfile, $TMPOUT1, $DELIM, "redo size")
  #
  # <wrap at> is specified in G(iga)

  # Some metrics wrap at 4G and continue with zero.
  # That may result in negative figures.
  # This function calculates the "correct" delta.

  my $wrapat = $_[0];
  my $PF     = $_[1];
  my $CF     = $_[2];
  my $D      = $_[3];
  my $EXPR   = $_[4];
  my $COL    = $_[5] || 2;

  my $v1 = trim(get_value($PF, $D, $EXPR, $COL));
  my $v2 = trim(get_value($CF, $D, $EXPR, $COL));
  print "PREVIOUS=$v1, CURRENT=$v2\n";

  # 4GB - previous value + current value
  my $v = ($wrapat * 1024 * 1024 * 1024) - $v1 + $v2;

  return($v);

} # recalc


# -------------------------------------------------------------------
sub clean_up {
  # clean_up(<file list>)
  #
  # Remove all left over files at script end.

  title(sub_name());

  # Remove temporary files.
  foreach my $file (@_) {
    if (-e $file) {
      print "Removing temporary file '$file' ...";
      if (unlink($file)) {print "Done.\n"}
      else {print "Failed.\n"}
    }
  }
} # clean_up


# -------------------------------------------------------------------
sub send_runtime {
  # The runtime of this script
  # send_runtime(<start_secs> [, {"s"|"m"|"h"}]);

  # Current time minus start time.
  my $rt = time - $_[0];

  my $unit =  "S";
  if ( $_[1] ) { $unit = uc($_[1]) }

  if    ($unit eq "M") { uls_value($IDENTIFIER, "runtime", pround($rt / 60.0, -1), "min") }
  elsif ($unit eq "H") { uls_value($IDENTIFIER, "runtime", pround($rt / 60.0 / 60.0, -2), "h") }
  else                 { uls_value($IDENTIFIER, "runtime", pround($rt, 0), "s") }


} # send_runtime


# ------------------------------------------------------------
sub send_doc {
  # send_doc(<title> [, <as title>])
  #
  # If the <title> is found in the $TESTSTEP_DOC hash, then
  # the associated text is sent as documentation to the ULS.
  # Remember: the teststep must exist in the ULS before any
  #           documentation can be saved for it.
  # If the alias <as title> is given, the associated text is
  # sent to the ULS for teststep <as title>. So you may even
  # document variable teststeps with constant texts. You may
  # substitute parts of the contents of the hash value, before
  # it is sent to the ULS.

  my $title = $_[0];
  my $astitle = $_[1] || $title;

  if (%TESTSTEP_DOC) {
    if ($TESTSTEP_DOC{lc($title)}) {
      # TODO: You may want to substitute <title> with <astitle> in the text?
      uls_doc($astitle, $TESTSTEP_DOC{lc($title)})
    } else {
      print "No documentation for '$title' found.\n";
    }
  }

} # send_doc


# ===================================================================
sub general_info {
  # Gather some general info about the current oracle instance

  # This sub returns a value, whether the rest of the script is
  # executed or not.

  title(sub_name());

  my $ts = "Info";

  # -----
  # Values from last run
  my $oracle_status_last   = $WORKFILE->val(sub_name(), "database status", "");
  my $oracle_dbrole_last   = $WORKFILE->val(sub_name(), "database role", "");
  my $oracle_version_last  = $WORKFILE->val(sub_name(), "oracle version", "");
  my $oracle_version_full_last  = $WORKFILE->val(sub_name(), "oracle version full", "");
  my $hostname_last        = $WORKFILE->val(sub_name(), "hostname", "");
  my $instname_last        = $WORKFILE->val(sub_name(), "instance name", "");
  my $logmode_last         = $WORKFILE->val(sub_name(), "database log mode", "");
  my $instance_startup_at_last  = $WORKFILE->val(sub_name(), "instance startup at", "");

  # Will be 1, if any of the values has changed since last run.
  my $something_has_changed = 0;

  # Values from this run
  $ORACLE_STATUS          = "unknown";
  $ORACLE_DBROLE          = "unknown";
  my $hostname            = "";
  my $instname            = "";
  my $oracompatible       = "";
  my $logmode             = "";
  my $instance_startup_at = iso_datetime();

  $WORKFILE_TIMESTAMP = $instance_startup_at;

  # ----- Check if Oracle is available
  my $sql = "
    select 'database status', status from v\$instance;
    SELECT 'database role', DATABASE_ROLE FROM V\$DATABASE;
  ";

  # STARTED
  # MOUNTED
  # OPEN
  # OPEN MIGRATE
  #
  # LOGICAL STANDBY
  # PHYSICAL STANDBY
  # PRIMARY

  my $abort_msg = "";

  if (exec_sql($sql)) {
    if (! errors_in_file($TMPOUT1)) {

      $ORACLE_STATUS = trim(get_value($TMPOUT1, $DELIM, "database status"));
      $ORACLE_DBROLE = trim(get_value($TMPOUT1, $DELIM, "database role"));

      if ( ($ONCE_A_DAY)                       )  { $something_has_changed = 1 }
      if ($ORACLE_STATUS ne $oracle_status_last)  { $something_has_changed = 1 }
      if ($ORACLE_DBROLE ne $oracle_dbrole_last)  { $something_has_changed = 1 }

    } else {
      $abort_msg = "Error: there have been errors when executing the sql statement.";
    }
  } else {
    $abort_msg = "Error: Cannot execute sql statement.";
  }

  # -----------------------------------------------------------------
  if ($abort_msg ne "") {
    # ABORT SCRIPT

    # It is a fatal error if that value cannot be derived.
    # uls_value($ts, "database status", $db_status, "[ ]");
    # uls_value($ts, "database role, status", "$db_role, $db_status", "[ ]");
    uls_value($ts, "database role, status", "$ORACLE_DBROLE, $ORACLE_STATUS", "[ ]");

    output_error_message(sub_name() . ": $abort_msg");
    uls_send_file_contents($IDENTIFIER, "message", $TMPOUT1);

    set_value(\$WORKFILE, sub_name(), "database status", $ORACLE_STATUS);
    set_value(\$WORKFILE, sub_name(), "database role", $ORACLE_DBROLE);
    # set_value(\$WORKFILE, sub_name(), "oracle version", $ORACLE_VERSION);
    # set_value(\$WORKFILE, sub_name(), "oracle version full", $ORACLE_VERSION_FULL);
    # set_value(\$WORKFILE, sub_name(), "hostname", $hostname);
    # set_value(\$WORKFILE, sub_name(), "instance name", $instname);
    # set_value(\$WORKFILE, sub_name(), "database log mode", $logmode);
    # set_value(\$WORKFILE, sub_name(), "instance startup at", $instance_startup_at);

    return(0);
  } # ABORT SCRIPT
  # -----------------------------------------------------------------


  # ----- More information

  $sql = "
    select 'from_instance', version, replace(host_name, '\', '.'), instance_name, TO_CHAR(startup_time,'YYYY-MM-DD HH24:MI:SS') from v\$instance;
    select 'database log mode', log_mode from v\$database;
    select 'oracle compatible', value from v\$parameter where name = 'compatible';
  ";

  if (! do_sql($sql)) {return(0)}

  # $ORACLE_VERSION     = trim(get_value($TMPOUT1, $DELIM, "oracle version"));
  $ORACLE_VERSION     = trim(get_value($TMPOUT1, $DELIM, "from_instance", 2));
  $ORACLE_VERSION_FULL = $ORACLE_VERSION;
  # e.g. 10.1.0.3.0, 10.2.0.3.0, 11.2.0.4.0, 12.1.0.2.0, 19.0.0.0.0

  ($ORACLE_MAJOR_VERSION, $ORACLE_MINOR_VERSION, my $dummy) = split(/\./, $ORACLE_VERSION, 3);
  $ORACLE_MAJOR_VERSION = int($ORACLE_MAJOR_VERSION);
  $ORACLE_MINOR_VERSION = int($ORACLE_MINOR_VERSION);

  $ORACLE_VERSION_3D = join(".", map(sprintf("%03d", $_), split(/\./, $ORACLE_VERSION) ) );
  # e.g. 010.002.000.003.000, 011.002.000.004.000, 012.001.000.002.000, 019.000.000.000.000
  # That allows exact comparisons of Oracle versions.

  $hostname            = trim(get_value($TMPOUT1, $DELIM, "from_instance", 3));
  $instname            = trim(get_value($TMPOUT1, $DELIM, "from_instance", 4));
  $instance_startup_at = trim(get_value($TMPOUT1, $DELIM, "from_instance", 5));
  $WORKFILE_TIMESTAMP = $instance_startup_at;
  $logmode             = trim(get_value($TMPOUT1, $DELIM, "database log mode"));
  $oracompatible       = trim(get_value($TMPOUT1, $DELIM, "oracle compatible"));

  # -----
  $sql = "";

  # Only Oracle 18 and later has this column
  if ($ORACLE_MAJOR_VERSION >= 18) {
    $sql .= "select 'oracle version full', version_full FROM v\$instance;";
  }
  # Only Oracle 12 and later has this column
  if ($ORACLE_MAJOR_VERSION >= 12) {
    if ( $sql ) { $sql .= "\n" }
    $sql .= "select 'is_cdb', cdb from v\$database;";
  }

  my $is_cdb = "NO";
  if ($sql ) {
    if (! do_sql($sql)) {return(0)}
    my $ovf = trim(get_value($TMPOUT1, $DELIM, "oracle version full"));
    if ( $ovf ) { $ORACLE_VERSION_FULL = $ovf }
    $is_cdb = uc(trim(get_value($TMPOUT1, $DELIM, "is_cdb")));
  }

  # -----
  if ($ONCE_A_DAY                                       ) { $something_has_changed = 1 }
  if ($ORACLE_VERSION      ne $oracle_version_last      ) { $something_has_changed = 1 }
  if ($ORACLE_VERSION_FULL ne $oracle_version_full_last ) { $something_has_changed = 1 }
  if ($ORACLE_DBROLE       ne $oracle_dbrole_last       ) { $something_has_changed = 1 }
  if ($hostname            ne $hostname_last            ) { $something_has_changed = 1 }
  if ($instname            ne $instname_last            ) { $something_has_changed = 1 }
  if ($logmode             ne $logmode_last             ) { $something_has_changed = 1 }
  if ($instance_startup_at ne $instance_startup_at_last ) { $something_has_changed = 1 }

  if ( $something_has_changed ) {
    # Send all values to ULS.
    # uls_value($ts, "database status", $db_status, "[ ]");
    uls_value($ts, "database role, status", "$ORACLE_DBROLE, $ORACLE_STATUS", "[ ]");
    uls_value($ts, "oracle version", $ORACLE_VERSION, "[ ]");

    # Only if the version differs from the full version
    if ($ORACLE_VERSION_FULL ne $ORACLE_VERSION) {
      uls_value($ts, "oracle version full", $ORACLE_VERSION_FULL, "[ ]");
    }
    uls_value($ts, "compatible", $oracompatible, "[ ]");

    uls_value($ts, "hostname", $hostname, "[ ]");
    uls_value($ts, "instance name", $instname, "[ ]");
    uls_value($ts, "database log mode", $logmode, "[ ]");
    uls_value($ts, "instance startup at", $instance_startup_at, "{DT}");
  }

  # -----
  # Save values of this run to workfile.
  set_value(\$WORKFILE, sub_name(), "database status", $ORACLE_STATUS);
  set_value(\$WORKFILE, sub_name(), "database role", $ORACLE_DBROLE);
  set_value(\$WORKFILE, sub_name(), "oracle version", $ORACLE_VERSION);
  set_value(\$WORKFILE, sub_name(), "oracle version full", $ORACLE_VERSION_FULL);
  set_value(\$WORKFILE, sub_name(), "hostname", $hostname);
  set_value(\$WORKFILE, sub_name(), "instance name", $instname);
  set_value(\$WORKFILE, sub_name(), "database log mode", $logmode);
  set_value(\$WORKFILE, sub_name(), "instance startup at", $instance_startup_at);

  # -----
  send_doc($ts);

  # -----
  if ( $is_cdb ne 'YES' ) {
    print "This is not a container database, no pluggable databases.\n";
    # No error, just leave the sub.
    return(1);  # ok
  } 
  # -----------------------------------------------------------------

  # Ok, we got pluggable databases
  # Leave out the PDBSEED

  $sql = "SELECT NAME, CON_ID FROM V\$PDBS WHERE CON_ID > 2 ORDER BY CON_ID;";
  if (! do_sql($sql)) {return(0)}

  # -----
  # Fill the global @PDB_LIST with all pdb names

  my @pdbs;
  get_value_lines(\@pdbs, $TMPOUT1);

  # Walk over all lines (which are PDBs)
  # Remember: each line contains a delimiter.

  foreach my $pdb (@pdbs) {

    my @p = split($DELIM, $pdb);
    @p = map(trim($_), @p);
    # There is only one PDB per line
    my ($p, $conid) = @p;

    push(@PDB_LIST, "$p|$conid");
  }

  return(1); # ok
} # general_info



# ===================================================================
sub general_pdb_info {
  # Gather some general info about the current pluggable database

  # This sub returns a value, whether the rest of the script is
  # executed or not.

  title(sub_name());

  my $ts = "Info PDB";

  # Values from last run
  my $last_open_mode = $WORKFILE->val(sub_name(), "open_mode_$CURRENT_PDB", "");
  my $last_open_time = $WORKFILE->val(sub_name(), "open_time_$CURRENT_PDB", "");

  print "last_open_mode=$last_open_mode, last_open_time=$last_open_time\n";

  my $sql = "
    select 'info', NAME, OPEN_MODE, OPEN_TIME, TOTAL_SIZE, BLOCK_SIZE from V\$PDBS where con_id = $CURRENT_CON_ID;
    select 'instance_name', instance_name from v\$instance;
  ";
  if (! do_sql($sql)) {return(0)}

  my $pdb_name    = trim(get_value($TMPOUT1, $DELIM, "info", 2));
  my $open_mode   = trim(get_value($TMPOUT1, $DELIM, "info", 3));
  my $open_time   = trim(get_value($TMPOUT1, $DELIM, "info", 4));
  my $total_size  = trim(get_value($TMPOUT1, $DELIM, "info", 5));
  my $block_size  = trim(get_value($TMPOUT1, $DELIM, "info", 6));
  my $cdb_name    = trim(get_value($TMPOUT1, $DELIM, "instance_name", 2));

  $total_size = sprintf("%0.1f", $total_size / 1024 / 1024 / 1024);
  $block_size = sprintf("%d", $block_size / 1024);

  print "cdb_name=$cdb_name, pdb_name=$pdb_name, open_mode=$open_mode, open_time=$open_time\n";
  print "total_size=$total_size GB, block_size=$block_size Byte\n";

  $WORKFILE_TIMESTAMP = $open_time;

  # if ( $total_size =~ /^\d+$/) { $total_size = sprintf("%0.1f", $total_size / 1024 / 1024 / 1024) }

  # Will be 1, if any of the values has changed since last run.
  my $something_has_changed = 0;

  if ($ONCE_A_DAY                    ) { $something_has_changed = 1 }
  if ($last_open_mode  ne  $open_mode) { $something_has_changed = 1 }
  if ($last_open_time  ne  $open_time) { $something_has_changed = 1 }

  if ( $something_has_changed ) {
    # Send all values to ULS.
    uls_value($ts, "pdb name", "$pdb_name", "[ ]");
    uls_value($ts, "cdb name", "$cdb_name", "[ ]");
    uls_value($ts, "open mode", $open_mode, "[ ]");
    uls_value($ts, "open time", $open_time, "{DT}");
    uls_value($ts, "total size", $total_size, "GB");
    uls_value($ts, "block size", $block_size, "kB");
  }

  set_value(\$WORKFILE, sub_name(), "open_mode_$CURRENT_PDB", $open_mode);
  set_value(\$WORKFILE, sub_name(), "open_time_$CURRENT_PDB", $open_time);

  # -----
  send_doc($ts);

} # general_pdb_info



# ===================================================================
sub tablespace_usage {

  # -----------------------------------------------------------------
  title(sub_name());

  my $tstep = "tablespace usage";

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  # -----
  # List of all tablespaces and their contents (PERMANENT, TEMP, UNDO, ...)

  my $sql = "select tablespace_name, contents from dba_tablespaces order by 1; ";

  if (! do_sql($sql)) {return(0)}

  my @T;
  get_value_lines(\@T, $TMPOUT1);

  # Summary size of all tablespaces, including the temporary tablespaces.
  my $size_sum = 0;

  # -----
  # Walk over all tablespaces
  foreach my $t (@T) {

    my @E = split($DELIM, $t);
    @E = map(trim($_), @E);
    # Do not use upper case, tablespace names may be in lowercase.
    # @E = map(uc($_), @E);

    my ($ts_name, $contents) = @E;
    $contents = uc($contents);
    print "Usage for $contents tablespace: $ts_name\n";

    # Is the tablespace contents supported?
    my $supported = "NO";

    # -----
    # TEMPORARY tablespaces

    if (" $contents " =~ / TEMPORARY /) {

      $supported = "yes";

      $sql = "
        variable ts varchar2(30)
        exec :ts := '$ts_name'

        select 'lazy', nvl(sum(BYTES_FREE), 0), nvl(sum(BYTES_USED), 0) from V\$TEMP_SPACE_HEADER where tablespace_name = :ts;
        select 'current', nvl(sum(bytes_used), 0) from v\$temp_extent_pool where tablespace_name = :ts;

        select 'max_auto_extensible', nvl(sum( greatest(maxbytes, bytes)), 0)
          from dba_temp_files
          where tablespace_name = :ts and autoextensible = 'YES';

        select 'max_non_extensible', nvl(sum( greatest(maxbytes, bytes)), 0)
          from dba_temp_files
          where tablespace_name = :ts and autoextensible = 'NO';

      ";

      if (! do_sql($sql)) {return(0)}

      # Max potential size that the temp files can grow to
      my $potential_max_size = trim(get_value($TMPOUT1, $DELIM, "max_auto_extensible"));
      $potential_max_size   += trim(get_value($TMPOUT1, $DELIM, "max_non_extensible"));
      uls_value("$tstep:$ts_name", "potential max size", bytes2gb($potential_max_size), "GB");

      # The space within the temporary tablespaces is only lazily
      # reused (stays occupied until needed for operation). The better
      # information about the usage of the temp tablespace is the
      # v$temp_extent_pool, which keeps the currently occupied space
      # by objects in the temp tablespace.

      my $free_lazy = trim(get_value($TMPOUT1, $DELIM, "lazy", 2));
      my $used_lazy = trim(get_value($TMPOUT1, $DELIM, "lazy", 3));
      my $used      = trim(get_value($TMPOUT1, $DELIM, "current", 2));

      # my $free_lazy = $size - $used_lazy;
      my $size = $used_lazy + $free_lazy;

      my $free = $size - $used;

      # uls_value("$tstep:$ts_name", "size",        pround($size / $MB, -1),      "MB");
      # uls_value("$tstep:$ts_name", "used (lazy)", pround($used_lazy / $MB, -1), "MB");
      # uls_value("$tstep:$ts_name", "free (lazy)", pround($free_lazy / $MB, -1), "MB");
      # uls_value("$tstep:$ts_name", "size",        bytes2gb($size),      "GB");

      uls_value("$tstep:$ts_name", "current size", bytes2gb($size),      "GB");
      uls_value("$tstep:$ts_name", "used (lazy)",  bytes2gb($used_lazy), "GB");

      # That one is now calculated on demand in ULS:
      # uls_value("$tstep:$ts_name", "free (lazy)", bytes2gb($free_lazy), "GB");

      # if (abs($size) > $VERY_SMALL) {
      #   uls_value("$tstep:$ts_name", "%used (lazy)", pround(100.0 / $size * $used_lazy, -1), "%");
      # }

      # uls_value("$tstep:$ts_name", "used", pround($used / $MB, -1), "MB");
      # uls_value("$tstep:$ts_name", "free", pround($free / $MB, -1), "MB");

      uls_value("$tstep:$ts_name", "used", bytes2gb($used), "GB");

      # That one is now calculated on demand in ULS:
      # uls_value("$tstep:$ts_name", "free", bytes2gb($free), "GB");

      # if (abs($size) > $VERY_SMALL) {
      #   uls_value("$tstep:$ts_name", "%used", pround(100.0 / $size * $used, -1), "%");
      # }

      # %used is now calculated on "potential max size" and named: %used_pms
      if (abs($potential_max_size) > $VERY_SMALL) {
        uls_value("$tstep:$ts_name", "%used_pms", pround(100.0 / $potential_max_size * $used, -1), "%");
      }


      send_doc($tstep, "$tstep:$ts_name");

      $size_sum += $size;
    } # TEMP


    # -----
    # PERMANENT and UNDO tablespaces

    if (" $contents " =~ / PERMANENT | UNDO /) {
    
      $supported = "yes";

      $sql = "
        variable ts varchar2(30)
        exec :ts := '$ts_name'

        select 'size', nvl(sum(bytes), 0) from dba_data_files where tablespace_name = :ts;
        select 'free', nvl(sum(bytes), -1) from dba_free_space where tablespace_name = :ts;

        select 'max_auto_extensible', nvl(sum( greatest(maxbytes, bytes)), 0)
          from dba_data_files
          where tablespace_name = :ts and autoextensible = 'YES';

        select 'max_non_extensible', nvl(sum( greatest(maxbytes, bytes)), 0)
          from dba_data_files
          where tablespace_name = :ts and autoextensible = 'NO';

      ";

      if (! do_sql($sql)) {return(0)}

      # Max potential size that the data files can grow to
      my $potential_max_size = trim(get_value($TMPOUT1, $DELIM, "max_auto_extensible"));
      $potential_max_size   += trim(get_value($TMPOUT1, $DELIM, "max_non_extensible"));
      uls_value("$tstep:$ts_name", "potential max size", bytes2gb($potential_max_size), "GB");

      my $size = trim(get_value($TMPOUT1, $DELIM, "size"));

      my $free = trim(get_value($TMPOUT1, $DELIM, "free"));
      # free may be NULL, if there are no objects living
      # in this tablespace. It is assumed to be empty then.
      if (! $free) {$free = $size}

      # It may be -1 (NULL), if no free space is left over
      if ($free == -1) {$free = 0}

      my $used = $size - $free;

      # uls_value("$tstep:$ts_name", "size", pround($size / $MB, -1), "MB");
      # uls_value("$tstep:$ts_name", "used", pround($used / $MB, -1), "MB");
      # uls_value("$tstep:$ts_name", "free", pround($free / $MB, -1), "MB");

      uls_value("$tstep:$ts_name", "size", bytes2gb($size), "GB");
      uls_value("$tstep:$ts_name", "used", bytes2gb($used), "GB");

      # uls_value("$tstep:$ts_name", "free", bytes2gb($free), "GB");

      # if (abs($size) > $VERY_SMALL) {
      #   uls_value("$tstep:$ts_name", "%used", pround(100.0 / $size * $used, -1), "%");
      # }

      if (abs($potential_max_size) > $VERY_SMALL) {
        uls_value("$tstep:$ts_name", "%used_pms", pround(100.0 / $potential_max_size * $used, -1), "%");
      }

      send_doc($tstep, "$tstep:$ts_name");

      $size_sum += $size;

    } # PERMANENT, UNDO


    # -----
    # UNDO tablespace (same as PERMANENT, plus these specials for UNDO)

    if (" $contents " =~ / UNDO /) {

      $supported = "yes";

      undo_usage("$tstep:$ts_name", $ts_name);
      send_doc($tstep, "$tstep:$ts_name");

    } # UNDO specials


    # -----
    # Other tablespace contents may be possible.
    # This one is currently not supported!

    if ($supported !~ /yes/i) {
      output_error_message(sub_name() . ": Error: tablespace with contents '$contents' is currently not supported.");
    }

  } # foreach tablespace

  uls_value($tstep, "size of all", pround($size_sum / $GB, -1), "GB");

  send_doc($tstep);

  return(1);

} # tablespace_usage


# ===================================================================
sub wait_event_classes {

  # It has turned out to be not of much use:
  #   if the system is slow, you may look at the system statistics
  #   if a session is slow, you may look at v$session_wait_class.
  #
  # There are sometimes negative differences for wait class 'Other', 
  # don't know why! I ignore that like 'Idle'.

  title(sub_name());

  # Not available before Oracle 10
  # if ($ORACLE_VERSION !~ /^1\d/) { return(1) }
  if ($ORACLE_MAJOR_VERSION < 10) {return(1)}


  my $ts = "wait event classes";

  # That's the file where the values are stored until the next run.
  my $workfile = "$WORKFILEPREFIX.wait_event_classes";

  # Omit the "idle", that would spoil the percentage calculation.
  # Although it may nevertheless be an interesting figure.

  my $sql = "
    variable wc1 varchar2(10)
    exec :wc1 := 'idle'

    variable wc2 varchar2(10)
    exec :wc2 := 'other'

    select
       wait_class
      ,total_waits
      ,time_waited
     from v\$system_wait_class
     where lower(wait_class) != :wc1
       and lower(wait_class) != :wc2
     ;
  ";
  #  where lower(wait_class) != 'idle'

  if (! do_sql($sql)) {return(0)}

  # workfile zeroed?
  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);

  if (! $wz) {
    # Only, if the workfile has not been zeroed.

    # -----
    # The lines of the workfile (previous values)
    my %PrevWaits;
    my %PrevWaitd;

    my @PREV;
    get_value_lines(\@PREV, $workfile);

    foreach my $line (@PREV) {
      my @E = split($DELIM, $line);
      @E = map(trim($_), @E);
      my ($wait_class, $total_waits, $time_waited) = @E;

      $PrevWaits{$wait_class} = $total_waits;
      $PrevWaitd{$wait_class} = $time_waited;

    } # foreach

    # -----
    # The lines with the current values
    my @CURR;
    get_value_lines(\@CURR, $TMPOUT1);

    # The lines with the differences between current and previous
    my @DIFF;

    # calculate the sum of all total waits and the overall time waited
    my $sum_waits = 0;
    my $sum_waited = 0;

    foreach my $line (@CURR) {
      my @E = split($DELIM, $line);
      @E = map(trim($_), @E);
      my ($wait_class, $total_waits, $time_waited) = @E;

      my $prev_total_waits = $PrevWaits{$wait_class} || 0;
      my $diff_total_waits = $total_waits - $prev_total_waits;
      $sum_waits  += $diff_total_waits;

      my $prev_time_waited = $PrevWaitd{$wait_class} || 0;
      my $diff_time_waited = ($time_waited - $prev_time_waited) * 10; # now in ms
      $sum_waited += $diff_time_waited;

      push(@DIFF, "$wait_class$DELIM$diff_total_waits$DELIM$diff_time_waited");
    } # foreach


    # -----

    foreach my $line (@DIFF) {
      my @E = split($DELIM, $line);
      @E = map(trim($_), @E);
      my ($wait_class, $diff_total_waits, $diff_time_waited) = @E;

      my $teststep = "$ts:$wait_class";

      uls_value($teststep, "total waits", $diff_total_waits, "#");
      uls_value($teststep, "time waited", $diff_time_waited, "ms");

      if (abs($diff_total_waits) > $VERY_SMALL) {
        # average wait time for one wait
        uls_value($teststep, "average time waited", sprintf($PC_FMT, $diff_time_waited / $diff_total_waits), "ms");
      }

      if (abs($sum_waits) > $VERY_SMALL) {
        # percentage of class waits to all waits
        uls_value($teststep, "ratio to sum total waits", sprintf($PC_FMT, 100 / $sum_waits * $diff_total_waits), "%");
      }

      if (abs($sum_waited) > $VERY_SMALL) {
        # percentage of class wait time to accumulated wait time
        uls_value($teststep, "ratio to sum time waited", sprintf($PC_FMT, 100 / $sum_waited * $diff_time_waited), "%");
      }

      send_doc($ts, $teststep);

    } # foreach

  } # if

  make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);

  return(1);

} # wait_event_classes


# ===================================================================
sub wait_events {

  title(sub_name());

  my $ts = "wait events";

  # That's the file where the values are stored until the next run.
  my $workfile = "$WORKFILEPREFIX.wait_events";

  my $sql = "
    select event, total_waits, total_timeouts, time_waited, average_wait from v\$system_event;
  ";

  if (! do_sql($sql)) {return(0)}

  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);

  if (! $wz) {
    # Only if workfile not zeroed!

    my @EV = get_value_list($TMPOUT1, $DELIM, 1);

    my @u = ();

    foreach my $ev (@EV) {
      my $ev_name = trim($ev);
      my @v = ();

      if (defined(get_value($TMPOUT1, $DELIM, $ev, 1))) {

        my $total_waits = trim(delta_value($workfile, $TMPOUT1, $DELIM, $ev, 2));
        push(@v, "total waits:$total_waits:#");

        my $total_touts = trim(delta_value($workfile, $TMPOUT1, $DELIM, $ev, 3));
        push(@v, "total timeouts:$total_touts:#");

        my $time_waited = trim(delta_value($workfile, $TMPOUT1, $DELIM, $ev, 4));
        $time_waited = $time_waited * 10;
        push(@v, "time waited:$time_waited:ms");

        # It even is a calculated figure?
        if (abs($total_waits) > $VERY_SMALL) {
          push(@v, "average wait:" . pround($time_waited / $total_waits, -3) . ":ms");
        }

        uls_nvalues("$ts:$ev_name", \@v);
        send_doc($ts, "$ts:$ev_name");

      } else {
        print "No wait statistics found for '$ev'.\n";
      }
    } # foreach
  }

  make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);


  return(1);

} # wait_events


# ===================================================================
sub sessions_processes {

  title(sub_name());

  # my $ts = "sessions and processes";
  my $ts = "processes";

  #  -- select 'sessions', count(*) from v\$session;

  my $sql = "
    variable n varchar2(10)
    exec :n := 'processes'

    variable mpcn varchar2(20)
    exec :mpcn := 'max processes count'

    select 'processes', count(*) from v\$process;
    select 'max_processes', value from v\$parameter where lower(name)  = :n ;
    select 'max_processes_since_startup', value from v\$pgastat where lower(name) = :mpcn;
  ";

  if (! do_sql($sql)) {return(0)}

  my $P = trim(get_value($TMPOUT1, $DELIM, "processes"));
  # my $S = trim(get_value($TMPOUT1, $DELIM, "sessions"));
  my $M = trim(get_value($TMPOUT1, $DELIM, "max_processes"));
  my $MPC = trim(get_value($TMPOUT1, $DELIM, "max_processes_since_startup"));

  if ( $ONCE_A_DAY ) {
    uls_value($ts, "max processes", $M, "#");
  }

  uls_value($ts, "processes", $P, "#");
  # uls_value($ts, "sessions", $S, "#");
  uls_value($ts, "max processes since startup", $MPC, "#");

  send_doc($ts);

  return(1);

} # sessions_processes


# ===================================================================
sub sessions_processes_pdb {

  title(sub_name());

  # my $ts = "sessions and processes";
  my $ts = "processes";

  # -- select 'sessions', count(*) from v\$session;
  # -- select 'max_processes', value from v\$parameter where lower(name)  = :n ;

  my $sql = "
    variable n varchar2(10)
    exec :n := 'processes'

    variable mpcn varchar2(20)
    exec :mpcn := 'max processes count'

    select 'processes', count(*) from v\$process where con_id = $CURRENT_CON_ID;
    select 'max_processes_since_startup', value from v\$pgastat where lower(name) = :mpcn;
  ";

  if (! do_sql($sql)) {return(0)}

  my $P = trim(get_value($TMPOUT1, $DELIM, "processes"));
  # my $S = trim(get_value($TMPOUT1, $DELIM, "sessions"));
  # my $M = trim(get_value($TMPOUT1, $DELIM, "max_processes"));
  my $MPC = trim(get_value($TMPOUT1, $DELIM, "max_processes_since_startup"));

  #if ( $ONCE_A_DAY ) {
  #  uls_value($ts, "max processes", $M, "#");
  #}

  uls_value($ts, "processes", $P, "#");
  # uls_value($ts, "sessions", $S, "#");
  uls_value($ts, "max processes since startup", $MPC, "#");

  send_doc($ts);

  return(1);

} # sessions_processes_pdb


# ===================================================================
sub grouped_connections {

  title(sub_name());

  my $ts = "grouped connections";

  my $and_con_id = "";
  if ( $CURRENT_PDB ) {
    $and_con_id = " and prc.con_id = $CURRENT_CON_ID and prc.con_id = ses.con_id "
    # That may not be placed in a single line,
    # always attach that to an already existing line.
  }

  #  -- and machine != UTL_INADDR.get_host_name

  my $sql = "
    select ses.program, ses.machine, ses.osuser, ses.username, count(*)
    from v\$process prc, v\$session ses
    where prc.addr = ses.paddr   $and_con_id
      and ses.username is not null
    group by ses.program, ses.machine, ses.osuser, ses.username
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my @L;

  get_value_lines(\@L, $TMPOUT1);

  foreach my $Line (@L) {

    my @E = split($DELIM, $Line);
    @E = map(trim($_), @E);
    my ($prog, $mach, $osus, $dbus, $cnt) = @E;

    my $tstep = "$ts: $prog: $mach: $osus: $dbus";
    uls_value($tstep, "count", $cnt, "#");
    send_doc($ts, $tstep);

  } # foreach

  return(1);
} # grouped_connections


# ===================================================================
sub rollback_segment_summary {

  title(sub_name());

  # TODO
  # this sub needs correction for CDB/PDB usage

  my $TS = "rollback segments";

  # That's the file where the values are stored until the next run.
  my $workfile = "$WORKFILEPREFIX.rollback_segment_summary";

  my $sql = "
  select 'unused',
      sum(rssize),
      sum(gets), sum(writes),
      sum(xacts),
      sum(extents),
      sum(shrinks), sum(wraps),
      sum(waits),
      sum(extends)
    from v\$rollstat;
  ";

  if (! do_sql($sql)) {return(0)}

  # workfile zeroed?
  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);

  my $unused = "unused";

  # The size is a current snapshot, so don't use delta_value!
  my $rssize  = trim(get_value($TMPOUT1, $DELIM, $unused, 2));
  my $gets    = trim(delta_value($workfile, $TMPOUT1, $DELIM, $unused, 3));
  my $writes  = trim(delta_value($workfile, $TMPOUT1, $DELIM, $unused, 4));

  if ($writes < 0) {
    print "'writes' original (negative)=$writes, recalculating...\n";
    $writes = recalc(4, $workfile, $TMPOUT1, $DELIM, $unused, 4);
    print "'writes' recalculated=$writes\n";
  }

  my $xacts   = trim(get_value($TMPOUT1, $DELIM, $unused, 5));
  my $extents = trim(get_value($TMPOUT1, $DELIM, $unused, 6));
  my $shrinks = trim(delta_value($workfile, $TMPOUT1, $DELIM, $unused, 7));
  my $wraps   = trim(delta_value($workfile, $TMPOUT1, $DELIM, $unused, 8));
  my $waits   = trim(delta_value($workfile, $TMPOUT1, $DELIM, $unused, 9));
  my $extends = trim(delta_value($workfile, $TMPOUT1, $DELIM, $unused, 10));

  if (! $wz) {
    uls_nvalues($TS, [ "size of rollback segment:$rssize:Bytes"
                     , "number of extents:$extents:#"
                     , "header gets:$gets:#"
                     , "header waits:$waits:#"
                     , "written to rollback segment:$writes:Bytes"
    ]);
  }


  make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);

  send_doc($TS);

  return(1);

} # rollback_segment_summary


# ===================================================================
sub library_caches {
  # memory : shared pool : library cache

  # TODO
  # this sub needs correction for CDB/PDB usage


  # select namespace, gethitratio from v$librarycache;
  # GETS GETHITS GETHITRATIO PINS PINHITS PINHITRATIO
  # RELOADS INVALIDATIONS DLM_LOCK_REQUESTS DLM_PIN_REQUESTS
  # DLM_PIN_RELEASES DLM_INVALIDATION_REQUESTS DLM_INVALIDATIONS

  #
  # NAMESPACE       GETHITRATIO PINHITRATIO
  # --------------- ----------- -----------
  # SQL AREA          .99766899  .999717668
  # TABLE/PROCEDURE  .995731329   .99966803
  # BODY             .998981685  .998910004
  # TRIGGER          .998350271  .998350271
  # INDEX            .999882064  .999862397
  # CLUSTER          .994900561  .992248062
  # OBJECT                    1           1
  # PIPE                      1           1
  # JAVA SOURCE               1           1
  # JAVA RESOURCE    .272727273       .1875
  # JAVA DATA        .989473684   .99338843

  title(sub_name());

  my $ts = "library cache";

  # That's the file where the values are stored until the next run.
  my $workfile = "$WORKFILEPREFIX.library_caches";

  my $sql = "
    select namespace, gets, gethits, pins, pinhits, reloads, invalidations from v\$librarycache;
  ";

  if (! do_sql($sql)) {return(0)}

  # workfile zeroed?
  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);

  my @N = get_value_list($TMPOUT1, $DELIM, 1);
  my @u = ();

  my ($all_gets, $all_pins, $all_gethits, $all_pinhits, $all_reloads, $all_invalidations) = (0,0,0,0,0,0);

  foreach my $n (@N) {
    my $n_name = trim($n);
    $n_name = lc($n_name);

    my $gets    = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n, 2));
    my $gethits = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n, 3));
    my $pins    = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n, 4));
    my $pinhits = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n, 5));
    my $reloads = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n, 6));
    my $invalidations = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n, 7));

    $all_gets += $gets;
    $all_gethits += $gethits;
    $all_pins += $pins;
    $all_pinhits += $pinhits;
    $all_reloads += $reloads;
    $all_invalidations += $invalidations;

    if ($OPTIONS =~ /DETAILED_LIBRARY_CACHE,/) {
      # only if the detailed library cache is enabled
      if ($gets + $gethits + $pins + $pinhits + $reloads + $invalidations > 0) {
        my @u = ();

        push(@u, "gets:$gets:#");
        push(@u, "gethits:$gethits:#");
        push(@u, "pins:$pins:#");
        push(@u, "pinhits:$pinhits:#");
        push(@u, "reloads:$reloads:#");
        push(@u, "invalidations:$invalidations:#");

        if (abs($gets) > $VERY_SMALL) {
          push(@u, "gethitratio:" . pround(100.0 / $gets * $gethits, -1) . ":%");
        }

        if (abs($pins) > $VERY_SMALL) {
          push(@u, "pinhitratio:" . pround(100.0 / $pins * $pinhits, -1) . ":%");
        }
        if (! $wz) {uls_nvalues("$ts:$n_name", \@u)}
      } # if > 0
    } # if DETAILED_LIBRARY_CACHE

  } # foreach

  @u = ();

  push(@u, "gets:$all_gets:#");
  push(@u, "gethits:$all_gethits:#");
  push(@u, "pins:$all_pins:#");
  push(@u, "pinhits:$all_pinhits:#");
  push(@u, "reloads:$all_reloads:#");
  push(@u, "invalidations:$all_invalidations:#");

  if (abs($all_gets) > $VERY_SMALL) {
    push(@u, "gethitratio:" . pround(100.0 / $all_gets * $all_gethits, -1) . ":%");
  }

  if (abs($all_pins) > $VERY_SMALL) {
    push(@u, "pinhitratio:" . pround(100.0 / $all_pins * $all_pinhits, -1) . ":%");
  }

  if (! $wz) {uls_nvalues($ts, \@u)}

  make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);

  send_doc($ts);

  return(1);

} # library_caches


# ===================================================================
sub buffer_cache_hit_ratio9 {

  title(sub_name());

  my ($ts, $workfile) = @_;

  my $sql = "
  select name, value from v\$sysstat
    where name in (
        'session logical reads'
      , 'physical reads'
      , 'physical reads direct'
      , 'physical reads direct (lob)'
      , 'db block gets'
      , 'consistent gets'
    )
    order by name;
  ";

  # Buffer Cache Hit Ratio = 1 - ((physical reads - physical reads direct - physical reads direct (lob)) /
  # (db block gets + consistent gets - physical reads direct - physical reads direct (lob))

  if (! do_sql($sql)) {return(0)}

  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);

  my $slr = trim(delta_value($workfile, $TMPOUT1, $DELIM, 'session logical reads'));
  my $phr = trim(delta_value($workfile, $TMPOUT1, $DELIM, 'physical reads'));
  my $prd = trim(delta_value($workfile, $TMPOUT1, $DELIM, 'physical reads direct'));
  my $prdl = trim(delta_value($workfile, $TMPOUT1, $DELIM, 'physical reads direct (lob)'));
  my $dbg = trim(delta_value($workfile, $TMPOUT1, $DELIM, 'db block gets'));
  my $cog = trim(delta_value($workfile, $TMPOUT1, $DELIM, 'consistent gets'));

  my $z = $phr - $prd - $prdl;
  my $n = $dbg + $cog - $prd - $prdl;

  if (abs($n) > $VERY_SMALL) {
    my $p = 100.0 * (1 - $z / $n);
    if ($p < 0.0) {$p = 0.0};  # whyever, sometimes we got negative numbers for INPOL.
    if ($p > 100.0) {$p = 100.0};  # whyever, sometimes we too high numbers
    if (! $wz) {uls_value($ts, "hit ratio", pround($p, -1), "%")}
  }

  make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);

}  # buffer_cache_hit_ratio9



# ===================================================================
sub buffer_cache9 {
  # memory : buffer cache

  title(sub_name());

  my $ts = "buffer cache (simple)";

  # ----- buffer cache size -----
  # For Oracle 9i that one worked:
  #  select component, current_size
  #    from v\$sga_dynamic_components
  #    where component = 'buffer cache';

  # This was used until 2006-09-20:
  # select 'buffer cache', sum(current_size)
  #   from v\$sga_dynamic_components
  #   where component like '%buffer cache';
  # select 'buffer used', block_size * sum(buffers)
  #   from v\$buffer_pool
  #   group by block_size;

  # The following works for Oracle9i and 10g.
  # There are several buffer caches in 10g, though.
  # select 'buffer cache', current_size from v$buffer_pool;

  my $sql = "
    select 'buffer cache',
           current_size * 1048576,
           block_size * buffers
      from v\$buffer_pool;
  ";

  if (! do_sql($sql)) {return(0)}

  my $s = trim(get_value($TMPOUT1, $DELIM, "buffer cache", 2));
  my $u = trim(get_value($TMPOUT1, $DELIM, "buffer cache", 3));

  uls_nvalues($ts, [
      "size:" . pround($s/$MB, -1) . ":MB"
    , "used:" . pround($u/$MB, -1) . ":MB"
  ]);

  # ----- buffer cache hit ratio -----
  # That's the file where the values are stored until the next run
  my $workfile = "$WORKFILEPREFIX.buffer_cache";

  # for Oracle 9.2
  buffer_cache_hit_ratio9($ts, $workfile);

  send_doc($ts);

  return(1);

} # buffer_cache9



# ===================================================================
sub buffer_cache_hit_ratio10_obsolete {

  title(sub_name());

  my ($ts, $workfile) = @_;

  # for 10g from "Database Performance Tuning Guide"
  my $sql = "
    SELECT NAME, VALUE FROM V\$SYSSTAT
      WHERE NAME IN (
         'db block gets from cache',
         'consistent gets from cache',
         'physical reads cache')
      order by name;
  ";

  # NAME                                                                  VALUE
  # ---------------------------------------------------------------- ----------
  # consistent gets from cache                                           608407
  # db block gets from cache                                              17894
  # physical reads cache                                                  14005

  # 1 - (('physical reads cache') / ('consistent gets from cache' + 'db block gets from cache')
  #
  # Works also for Oracle 11, see:
  #   Oracle® Database Performance Tuning Guide
  #   11g Release 1 (11.1)
  #   Part Number B28274-02
  #   7 Memory Configuration and Use
  #   7.2.2.3 Calculating the Buffer Cache Hit Ratio

  if (! do_sql($sql)) {return(0)}

  # workfile zeroed?
  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);

  my $prc = trim(delta_value($workfile, $TMPOUT1, $DELIM, 'physical reads cache'));
  my $cgfc = trim(delta_value($workfile, $TMPOUT1, $DELIM, 'consistent gets from cache'));
  my $bgfc = trim(delta_value($workfile, $TMPOUT1, $DELIM, 'db block gets from cache'));

  my $n = $cgfc + $bgfc;

  if (abs($n) > $VERY_SMALL) {
    my $p = 100.0 * (1 - $prc / $n);
    if ($p < 0.0) {$p = 0.0};
    if ($p > 100.0) {$p = 100.0};
    if (! $wz) {uls_value($ts, "hit ratio", pround($p, -1), "%")}
  }

  make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);

}  # buffer_cache_hit_ratio10_obsolete




# ===================================================================
sub buffer_cache_hit_ratio10 {
  title(sub_name());

  my ($ts) = @_;

  # for 10g from "Database Performance Tuning Guide"
  #my $sql = "
  #  SELECT NAME, VALUE FROM V\$SYSSTAT
  #    WHERE NAME IN (
  #       'db block gets from cache',
  #       'consistent gets from cache',
  #       'physical reads cache')
  #    order by name;
  #";

  my $sql = "
    select 
        name || ' (' || block_size / 1024 || 'k)'
      , physical_reads
      , db_block_gets + consistent_gets
      from v\$buffer_pool_statistics
    ;
  ";

  # NAME         PHYSICAL_READS DB_BLOCK_GETS+CONSISTENT_GETS
  # ------------ -------------- -----------------------------
  # KEEP (8k)                 0                             0
  # RECYCLE (8k)              0                             0
  # DEFAULT (8k)           3387                       1456770

  # hit ratio: (1-(physical_reads / (db_block_gets+consistent_gets)))*100
  # see:
  #   Oracle® Database Performance Tuning Guide
  #   10g Release 1 (10.1)
  #   Part Number B10752-01
  # 
  #   Chapter: Buffer Pool Hit Ratios
  #   (or equivalent for later Oracle releases)

  if (! do_sql($sql)) {return(0)}

  my $workfile = "$WORKFILEPREFIX.buffer_cache";
  # workfile zeroed?
  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);

  if (! $wz) {
    # Only if workfile has not been zeroed 
    # (which typically means that the instance has been restarted)

    my @LINES;
    get_value_lines(\@LINES, $TMPOUT1);

    foreach my $line (@LINES) {
      my @E = split($DELIM, $line);
      @E = map(trim($_), @E);

      my ($name, $reads, $gets) = @E;

      my $reads_prev = trim(get_value($workfile, $DELIM, $name, 2)) || 0;
      my $gets_prev  = trim(get_value($workfile, $DELIM, $name, 3)) || 0;

      my $reads_diff = $reads - $reads_prev;
      my $gets_diff  = $gets  - $gets_prev;

      if (abs($gets_diff) > $VERY_SMALL) {
        my $hit_ratio = ( 1 - $reads_diff / $gets_diff ) * 100.0;
        print "buffer cache hit ratio for '$name': $hit_ratio (basic calculation)\n";

        # only 0..100
        $hit_ratio = max(0, min($hit_ratio, 100));

        uls_value("$ts:$name", "hit ratio", pround($hit_ratio, -1), "%");
      }

    } # foreach
    make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);
  } # if

} # buffer_cache_hit_ratio10


# ===================================================================
sub buffer_cache {
  # New!
  # Now supporting different buffer caches like KEEP, DEFAULT with different 
  # block sizes, RECYCLE, ...

  # see e.g. http://www.praetoriate.com/t_v$buffer_pool_statistics.htm

  # TODO
  # this sub needs correction for CDB/PDB usage
  # Although only CON_ID=0 is currently found in the table data.


  # for Oracle 9.2
  if ($ORACLE_MAJOR_VERSION < 10) {
    # Use the old style for Oracle 9
    return(buffer_cache9());
  }

  # Here only for Oracle 10, 11

  title(sub_name());

  my $ts = "buffer cache";

  my $sql = "
    select 
        name || ' (' || block_size / 1024 || 'k)'
      , block_size
      , current_size
      , buffers
    from v\$buffer_pool
    order by name, block_size
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my @LINES;
  get_value_lines(\@LINES, $TMPOUT1);

  foreach my $line (@LINES) {
    my @E = split($DELIM, $line);
    @E = map(trim($_), @E);

    my ($name, $block_size, $current_size, $buffers) = @E;

    $current_size         = $current_size * 1048576;
    my $current_used      = $buffers * $block_size;
    my $block_size_kbytes = $block_size / 1024;

    uls_value("$ts:$name", "size", pround($current_size/$MB, -1), "MB");
    uls_value("$ts:$name", "used", pround($current_used/$MB, -1), "MB");
    send_doc($ts, "$ts:$name");

  } # foreach


  # Oracle 10, Oracle 11
  buffer_cache_hit_ratio10($ts);

  return(1);

} # buffer_cache


# ===================================================================
sub shared_pool {
  # memory : shared pool

  # TODO
  # this sub needs correction for CDB/PDB usage
  # Although only CON_ID=0 is currently found in V$sga_dynamic_components.
  # V$SGASTAT has (!) metrics for each container separately, but  
  # 'free memory' does (currently) only exist once for the complete shared pool.
  # So, this should work correctly for the cdb, but does not make sense for pdbs.

  title(sub_name());

  if ( $CURRENT_PDB ) {
    print "This sub does not deliver any metrics for pdbs, return without action.\n";
    return(1);
  }

  my $ts = "shared pool";

  # ----- shared pool size and free -----
  my $sql = "
    variable c varchar2(20)
    exec :c := 'shared pool'

    variable n varchar2(20)
    exec :n := 'free memory'

    select 'shared pool size', current_size from v\$sga_dynamic_components where component = :c;
    select 'shared pool free memory', bytes from v\$sgastat where pool = :c and name = :n;
  ";

  if (! do_sql($sql)) {return(0)}

  my $size = trim(get_value($TMPOUT1, $DELIM, "shared pool size"));
  my $free = trim(get_value($TMPOUT1, $DELIM, "shared pool free memory"));
  if ($free > $size) {$free = $size}  # this happens when shutting down
  my $used = $size - $free;

  my @u = ();
  push(@u, "size:" . pround($size/$MB, -1) . ":MB");
  push(@u, "used:" . pround($used/$MB, -1) . ":MB");
  push(@u, "free:" . pround($free/$MB, -1) . ":MB");

  if (abs($size) > $VERY_SMALL) {
    push(@u, "%used:" . pround(100.0 / $size * $used, -1) . ":%");
  }

  uls_nvalues($ts, \@u);

  send_doc($ts);

} # shared_pool


# ===================================================================
sub dictionary_cache {

  # TODO
  # this sub needs correction for CDB/PDB usage
  # Although only CON_ID=0 is currently found in the table data.

  title(sub_name());

  my $ts = "dictionary cache";

  # That's the file where the values are stored until the next run.
  my $workfile = "$WORKFILEPREFIX.dictionary_cache";

  my $sql = "
    SELECT 'dictionary cache', sum(gets), sum(getmisses), sum(fixed), sum(modifications)
    FROM V\$ROWCACHE;
  ";

  if (! do_sql($sql)) {return(0)}

  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);

  my $gets          = trim(delta_value($workfile, $TMPOUT1, $DELIM, 'dictionary cache', 2));
  my $getmisses     = trim(delta_value($workfile, $TMPOUT1, $DELIM, 'dictionary cache', 3));
  my $fixed         = trim(delta_value($workfile, $TMPOUT1, $DELIM, 'dictionary cache', 4));
  my $modifications = trim(delta_value($workfile, $TMPOUT1, $DELIM, 'dictionary cache', 5));

  my @u = ();

  push(@u, "gets:$gets:#");
  push(@u, "getmisses:$getmisses:#");
  push(@u, "fixed:$fixed:#");
  push(@u, "modifications:$modifications:#");

  if (abs($gets) > $VERY_SMALL) {
    push(@u, "overall hit ratio:" . pround(100 * ($gets - $getmisses - $fixed) / $gets, -1) . ":%");
  }

  if (! $wz) {uls_nvalues($ts, \@u)}

  make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);

  send_doc($ts);

  return(1);

} # dictionary_cache


# ===================================================================
sub dictionary_cache_detailed {
  # Generates a more detailed dictionary cache statistic.

  # TODO
  # this sub needs correction for CDB/PDB usage
  # Although only CON_ID=0 is currently found in the table data.

  title(sub_name());

  my $ts = "dictionary cache";

  # That's the file where the values are stored until the next run.
  my $workfile = "$WORKFILEPREFIX.dictionary_cache_detailed";

  #  , 100*sum(gets - getmisses) / sum(gets)  pct_succ_gets
  my $sql = "
    variable dc VARCHAR2(5)
    exec :dc := 'dc_%'

    SELECT parameter
     , sum(gets)
     , sum(getmisses)
     , sum(fixed)
     , sum(modifications)
    FROM V\$ROWCACHE
    WHERE lower(parameter) like :dc
    GROUP BY parameter
    ORDER BY parameter
    ;
  ";
  # There are a lot parameters, use just the dc_* ones.
  # Also, these are only discussed in the ODPT Guide.

  if (! do_sql($sql)) {return(0)}

  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);

  if (! $wz) {
    # Only if workfile not zeroed

    my @IDs = get_value_list($TMPOUT1, $DELIM, 1);

    foreach my $id (@IDs) {

      my $gets          = trim(delta_value($workfile, $TMPOUT1, $DELIM, $id, 2));
      my $getmisses     = trim(delta_value($workfile, $TMPOUT1, $DELIM, $id, 3));
      my $fixed         = trim(delta_value($workfile, $TMPOUT1, $DELIM, $id, 4));
      my $modifications = trim(delta_value($workfile, $TMPOUT1, $DELIM, $id, 5));

      if (($gets + $getmisses + $fixed + $modifications) > 0) {
        # only if any values have appeared, don't need all zeroes

        uls_value("$ts:$id", "gets", $gets, "#");
        uls_value("$ts:$id", "getmisses", $getmisses, "#");
        uls_value("$ts:$id", "fixed", $fixed, "#");
        uls_value("$ts:$id", "modifications", $modifications, "#");

        if (abs($gets) > $VERY_SMALL) {
          my $hit_ratio = pround(100.0 * ($gets - $getmisses - $fixed) / $gets, -1);
          $hit_ratio = min( max( $hit_ratio, 0), 100);
          uls_value("$ts:$id", "hit ratio", $hit_ratio, "%");
        }
        send_doc("detailed dictionary cache", "$ts:$id");
      }
    } # foreach
  }
  make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);


  return(1);

} # dictionary_cache_detailed


# ===================================================================
sub consumed_resources {

  title(sub_name());

  if ( ! $CURRENT_PDB ) {
    print "This sub is only usable for pluggable databases, do nothing\n";
    return(0);
  }

  my $ts = "consumed resources";

  # Use the entries of the last 10 minutes.
  my $last_dt = iso_datetime(time - 10*60);

  # -----
  #
  # SELECT con_id
  #       , sum(iops)                -- I/O operations per second
  #       , sum(iombps)              -- I/O megabytes per second
  #       , sum(CPU_CONSUMED_TIME)   -- in msec
  #       , max(SGA_BYTES)           -- current SGA usage by this PDB
  #       , max(BUFFER_CACHE_BYTES)  -- current usage of the buffer cache by this PDB
  #       , max(SHARED_POOL_BYTES)   -- current usage of the shared pool by this PDB
  #       , max(PGA_BYTES)           -- current PGA usage by this PDB
  # FROM   v$rsrcpdbmetric_history r
  # WHERE  r.con_id = 3
  # AND    begin_time > sysdate - 10 / (24 * 60)
  # group by con_id
  # ORDER BY con_id;

  # Sum or max metrics for the last 10 min are retrieved.
  # A 10 min cycle of script invocation is assumed.

  my $sql = "
    variable lastdt varchar2(20)
    exec :lastdt := '$last_dt'

    SELECT 'resource_consumption'
          , avg(iops)
          , avg(iombps)
          , avg(CPU_CONSUMED_TIME)
          , avg(SGA_BYTES)
          , avg(BUFFER_CACHE_BYTES)
          , avg(SHARED_POOL_BYTES)
          , avg(PGA_BYTES)
    FROM   v\$rsrcpdbmetric_history
    WHERE con_id = $CURRENT_CON_ID
      AND  to_char(begin_time, 'YYYY-MM-DD HH24:MI:SS') >= :lastdt
    group by con_id;
  ";

  if (! do_sql($sql)) {return(0)}

  my $iops        = trim(get_value($TMPOUT1, $DELIM, "resource_consumption", 2));
  my $iombps      = trim(get_value($TMPOUT1, $DELIM, "resource_consumption", 3));
  my $cpu_time    = trim(get_value($TMPOUT1, $DELIM, "resource_consumption", 4));
  my $sga_bytes   = trim(get_value($TMPOUT1, $DELIM, "resource_consumption", 5));
  my $bc_bytes    = trim(get_value($TMPOUT1, $DELIM, "resource_consumption", 6));
  my $sp_bytes    = trim(get_value($TMPOUT1, $DELIM, "resource_consumption", 7));
  my $pga_bytes   = trim(get_value($TMPOUT1, $DELIM, "resource_consumption", 8));

  $iops      = sprintf("%0.1f", $iops   );
  $iombps    = sprintf("%0.1f", $iombps );
  $cpu_time  = sprintf("%0.1f", $cpu_time   );
  $sga_bytes = sprintf("%0.1f", $sga_bytes / 1024 / 1024 );
  $bc_bytes  = sprintf("%0.1f", $bc_bytes  / 1024 / 1024 );
  $sp_bytes  = sprintf("%0.1f", $sp_bytes  / 1024 / 1024 );
  $pga_bytes = sprintf("%0.1f", $pga_bytes / 1024 / 1024 );

  uls_value($ts, "avg iops", $iops, "1/s");
  uls_value($ts, "avg iombps", $iombps, "MB/s");
  uls_value($ts, "cpu consumed time", $cpu_time, "ms");
  uls_value($ts, "SGA usage", $sga_bytes, "MB");
  uls_value($ts, "buffer cache usage", $bc_bytes, "MB");
  uls_value($ts, "shared pool usage", $sp_bytes, "MB");
  uls_value($ts, "PGA usage", $pga_bytes, "MB");

  send_doc($ts);

} # consumed_resources



# ===================================================================
sub sga {

  # TODO
  # this sub needs correction for CDB/PDB usage
  # Although only CON_ID=0 is currently found in the table data.
  title(sub_name());

  my $ts = "sga";

  # ----- sga -----
  # SQL> select * from v$sga;
  #
  # NAME                      VALUE
  # -------------------- ----------
  # Fixed Size               452284
  # Variable Size         520093696
  # Database Buffers      218103808
  # Redo Buffers             143360

  #my $sql = "
  #  select name, value from v\$sga;
  #  select 'overall size', sum(value) from v\$sga;
  #  select 'free memory', current_size from v\$sga_dynamic_free_memory;
  #";

  # Values from last run
  my $sga_size_last   = $WORKFILE->val(sub_name(), "sga_size", "0");

  # select 'free memory', current_size from v\$sga_dynamic_free_memory;

  my $sql = "select 'overall size', sum(value) from v\$sga;";

  if (! do_sql($sql)) {return(0)}

  my $sga_size = trim(get_value($TMPOUT1, $DELIM, "overall size"));
  $sga_size = pround($sga_size/$MB, -1);

  # my $free = trim(get_value($TMPOUT1, $DELIM, "free memory"));
  # $free = pround($free/$MB, -1);

  # uls_value_nodup({
  #    teststep  => $ts
  #  , detail    => "overall size"
  #  , value     => $size
  #  , unit      => "MB"
  #  , elapsed   => $DEFAULT_ELAPSED
  # });

  # uls_value_nodup({
  #    teststep  => $ts
  #  , detail    => "free memory"
  #  , value     => $free
  #  , unit      => "MB"
  #  , elapsed   => $DEFAULT_ELAPSED
  # });

  if ( ($ONCE_A_DAY) or ($sga_size_last != $sga_size) ) {
    uls_value($ts, "overall size", $sga_size, "MB");

  }

  set_value(\$WORKFILE, sub_name(), "sga_size", $sga_size);

  send_doc($ts);

} # sga


# ===================================================================
sub pga {

  # Currently, for Oracle 19.8, this select is correct.
  # V$PGASTAT only contains values for CON_ID=0 but these values
  # are different depending on the current container.
  # So, this is a bit confusing.

  title(sub_name());

  my $ts = "pga";

  # That's the file where the values are stored until the next run.
  my $workfile = "$WORKFILEPREFIX.pga";

  # ----- pga -----
  # SQL> select name, value from v$pgastat;
  #
  # NAME                                              VALUE
  # -------------------------------------------- ----------
  # aggregate PGA target parameter                786432000
  # aggregate PGA auto target                     703033344
  # global memory bound                            39321600
  # total PGA inuse                                 5283840
  # total PGA allocated                            10097664
  # maximum PGA allocated                          15448064
  # total freeable PGA memory                             0
  # PGA memory freed back to OS                    10485760
  # total PGA used for auto workareas                     0
  # maximum PGA used for auto workareas             3162112
  # total PGA used for manual workareas                   0
  # maximum PGA used for manual workareas                 0
  # over allocation count                                 0
  # bytes processed                              1777697792
  # extra bytes read/written                              0
  # cache hit percentage                                100

  my $sql = "select name, value from v\$pgastat;";

  if (! do_sql($sql)) {return(0)}

  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);

  my @u = ();

  my $n = "aggregate PGA target parameter";
  my $v = trim(get_value($TMPOUT1, $DELIM, $n));
  push(@u, "$n:" . pround($v/$MB, -1) . ":MB");

  $n = "aggregate PGA auto target";
  $v = trim(get_value($TMPOUT1, $DELIM, $n));
  push(@u, "$n:" . pround($v/$MB, -1) . ":MB");

  $n = "global memory bound";
  $v = trim(get_value($TMPOUT1, $DELIM, $n));
  push(@u, "$n:" . pround($v/$MB, -1) . ":MB");

  $n = "total PGA allocated";
  $v = trim(get_value($TMPOUT1, $DELIM, $n));
  push(@u, "$n:" . pround($v/$MB, -1) . ":MB");

  $n = "total PGA used for auto workareas";
  $v = trim(get_value($TMPOUT1, $DELIM, $n));
  push(@u, "$n:" . pround($v/$MB, -1) . ":MB");

  $n = "maximum PGA allocated";
  $v = trim(get_value($TMPOUT1, $DELIM, $n));
  push(@u, "$n:" . pround($v/$MB, -1) . ":MB");

  $n = "over allocation count";
  $v = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n));
  push(@u, "$n:$v:#");

  $n = "bytes processed";
  my $tbp = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n));
  push(@u, "total $n:" . pround($tbp/$MB, -1) . ":MB");

  $n = "extra bytes read/written";
  my $ebrw = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n));
  push(@u, "$n:" . pround($ebrw/$MB, -1) . ":MB");

  if (abs($tbp + $ebrw) > $VERY_SMALL) {
    push(@u, "cache hit ratio:" . pround($tbp * 100.0 / ($tbp + $ebrw), -1) . ":%");
  }

  if (! $wz) {uls_nvalues($ts, \@u)}

  make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);

  send_doc($ts);

} # pga


# ===================================================================
sub redo_logs {

  title(sub_name());

  my $ts = "redo logs";

  # That's the file where the values are stored until the next run.
  my $workfile = "$WORKFILEPREFIX.redo_logs";

  my $sql = "
    variable n1 varchar2(32)
    variable n2 varchar2(32)
    variable n3 varchar2(32)
    variable n4 varchar2(32)
    variable n5 varchar2(32)
    variable n6 varchar2(32)
    variable n7 varchar2(32)

    exec :n1 := 'redo entries'
    exec :n2 := 'redo size'
    exec :n3 := 'redo buffer allocation retries'
    exec :n4 := 'redo writes'
    exec :n5 := 'redo write time'
    exec :n6 := 'redo log space requests'
    exec :n7 := 'redo log space wait time'

    select name, value from v\$sysstat
      where name in (:n1, :n2, :n3, :n4, :n5, :n6, :n7)
      order by name;

    variable s varchar2(10)
    exec :s := 'CURRENT'

    select 'redo log switches', SEQUENCE# from v\$log where STATUS = :s;

    variable s2 varchar2(10)
    exec :s2 := 'INACTIVE'

    select 'inactive redo logs', count(*) FROM v\$log where STATUS = :s2;
  ";

  if (! do_sql($sql)) {return(0)}

  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);

  my @u = ();

  my $n = "redo entries";
  my $v = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n));
  push(@u, "$n:$v:#");

  $n = "redo size";

  $v = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n));

  if ($v < 0) {
    print "V original (negative)=$v, recalculating...\n";
    $v = recalc(4, $workfile, $TMPOUT1, $DELIM, $n);
    print "V recalculated=$v\n";
  }

  push(@u, "$n:" . pround($v/$MB, -1) . ":MB");

  $n = "redo buffer allocation retries";
  $v = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n));
  push(@u, "$n:$v:#");

  $n = "redo writes";
  $v = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n));
  push(@u, "$n:$v:#");

  #  Total elapsed time of the write from the redo log buffer to
  #  the current redo log file in 10s of milliseconds.
  $n = "redo write time";
  $v = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n));
  push(@u, "$n:" . pround($v*10.0/1000.0, -3) . ":s");

  $n = "redo log space requests";
  $v = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n));
  push(@u, "$n:$v:#");

  #  Total elapsed waiting time for "redo log space requests"
  #  in 10s of milliseconds
  $n = "redo log space wait time";
  $v = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n));
  push(@u, "$n:" . pround($v*10.0/1000.0, -3) . ":s");

  $n = "redo log switches";
  $v = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n));
  push(@u, "$n:$v:#");

  $n = "inactive redo logs";
  #  Sum of inactive redo log file to get a limit alert if zero
  $v = trim(get_value($workfile, $DELIM, $n));
  push(@u, "$n:$v:#");

  if (! $wz) {uls_nvalues($ts, \@u)}

  make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);

  # -----
  # Check the state of the redo log member files.

  title("redo log members");

  $sql = "select member, status from v\$logfile order by group#;";

  if (! do_sql($sql)) {return(0)}

  # Put first column into array @ts.
  my @members = get_value_list($TMPOUT1, $DELIM, 1);

  my $status = "";

  foreach my $member (@members) {
    my $stat = trim(get_value($TMPOUT1, $DELIM, $member));
    # '', 'INVALID', 'STALE', 'DELETED', ('' = ok)
    # $stat = "INVALID";   # for testing

    if ($stat) {
      # This members has a bad state
      if ($status) { $status .= "\n" }
      $status .= "$member = $stat";
    }

  } # foreach

  # uls_value($ts, "summary status all members", $status, " ");
  if ($status) { uls_value($ts, "status report", $status, "_") }

  send_doc($ts);

  return(1);

} # redo_logs



# ===================================================================
sub system_statistics {

  # TODO: 
  # V$SYSSTAT contains a column CON_ID but it is 0 for all entries. 
  # Although the metrics seem to be different in the cdb and in the pdbs.

  title(sub_name());

  my $ts = "system statistics";

  # That's the file where the values are stored until the next run.
  my $workfile = "$WORKFILEPREFIX.system_statistics";

  my $sql = "select name, value from v\$sysstat order by name; ";

  if (! do_sql($sql)) {return(0)}

  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);

  # , "DBWR checkpoint buffers written"
  my @N = (
    "db block changes"
  , "consistent changes"
  , "execute count"
  , "parse count (total)"
  , "parse count (hard)"
  , "physical reads"
  , "physical writes"
  , "table scan rows gotten"
  , "table fetch continued row"
  , "table scans (long tables)"
  , "table scans (short tables)"
  , "sorts (memory)"
  , "sorts (disk)"
  , "user calls"
  , "recursive calls"
  , "user commits"
  , "transaction rollbacks"
  , "user rollbacks"
  );

  # For flashback:
  #   physical reads for flashback new:
  #     If flashback is enabled, Oracle will read old undo blocks from the 
  #     undo tablespace and copy them into the flashback log before 'new'ing 
  #     them and using them.
  #   flashback log writes:
  #     ???

  # "consistent changes" contains both the following metrics:
  # consistent gets
  # consistent gets from cache
  #
  # Check "pga -- over allocation count" instead of the following:
  # workarea executions - optimal
  # workarea executions - onepass
  # workarea executions - multipass

  my @u = ();   # temporary array for uls values

  foreach my $n (@N) {
    my $v = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n));
    push(@u, "$n:$v:#");
  }
  if (! $wz) {uls_nvalues($ts, \@u)}

  make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);

  send_doc($ts);

  return(1);

} # system_statistics




# ===================================================================
sub find_alert {

  title(sub_name());

  my $bdump = "";

  my @ALERT_PATH = ();

  if ($ORACLE_MAJOR_VERSION >= 11) {

    # Oracle 11

    # Automatic Diagnostic Repository (ADR) Home
    # [diagnostic_dest]/diag/rdbms/[dbname]/[instname]

    # Ask the v$diag_info
    my $sql = "select lower(name), value from v\$diag_info; ";

    if (! do_sql($sql)) {return(undef)}

    # Derive the path and filename for the alert.log
    # May be in "diag trace"...
    $bdump = get_value($TMPOUT1, $DELIM, "diag trace");
    push(@ALERT_PATH, $bdump);

    # or in "diag alert".
    $bdump = get_value($TMPOUT1, $DELIM, "diag alert");
    push(@ALERT_PATH, $bdump);

  } else {

    # Oracle 9, Oracle 10

    my $sql = "
      variable n varchar2(25)
      exec :n := 'background_dump_dest'

      select name, value from v\$parameter where lower(name) = :n; 
    ";

    if (! do_sql($sql)) {return(undef)}

    # Derive the path and filename for the alert.log
    $bdump = get_value($TMPOUT1, $DELIM, "background_dump_dest");
    push(@ALERT_PATH, $bdump);
  }

  # -----
  # Search the directories for the alert.log
  foreach my $bd (@ALERT_PATH) {
    my $alert_log = "$bd/alert_" . $ENV{"ORACLE_SID"} . ".log";
    if (-r $alert_log) {
      return($alert_log);
    }

  } # foreach

  return("-not found-");

} # find_alert




# ===================================================================
sub alert_log {

  title(sub_name());

  # Transfer lines containing error messages from the alert.log file
  # to the ULS. An error count is also transferred, it is zero, when
  # no error are found. It starts from the last saved position within
  # the file.

  my $ts = "alert.log";

  # Trace file names found in alert.log
  my %TRACE_FILES;

  # location of alert.log
  my $alert_log = find_alert();

  # my $alert_log = "$bdump/alert_" . $ENV{"ORACLE_SID"} . ".log";
  print "alert log file=$alert_log\n";

  if ( "not found" =~ /$alert_log/i ) {
    output_error_message(sub_name() . ": Error: Cannot find path to alert.log, check the log file.");
    return(0);
  }
  if (! open(LOGFILE, $alert_log)) {
    output_error_message(sub_name() . ": Error: Cannot open '$alert_log' for reading: $!");
    return(0);
  }

  # Get file size of the alert.log
  my @s = stat(LOGFILE);
  my $fsize = $s[7];
  print "File size=$fsize Bytes\n";

  # That's the file where the line count is stored until the next run.
  my $workfile = "$WORKFILEPREFIX.alert_log_position";

  # my $last_pos = get_value($workfile, $DELIM, "last_position");
  my $last_pos = $WORKFILE->val(sub_name(), "last_position_in_alert", "");
  print "last processed position (found in workfile)=$last_pos\n";

  if ($last_pos !~ /\d+/) {
    # Try to use the old workfile
    print "Position not found in new workfile, try the old workfile.\n";
    # That's the file where the line count is stored until the next run.
    my $wrkfile = "$WORKFILEPREFIX.alert_log_position";

    $last_pos = get_value($wrkfile, $DELIM, "last_position");
    print "last processed position (found in old workfile)=$last_pos\n";
  }

  if ($last_pos !~ /\d+/) {
    # When there are no digits in $last_pos => very first run of script.
    uls_value($ts, "action", "very first run => start file from beginning", "[ ]");
    $last_pos = 0;
  }
  print "last processed position=$last_pos (in Bytes from beginning of file).\n";

  # If file has shrunk compared to previous run.
  if ($last_pos > $fsize) {
    print "File size ($fsize) has shrunk since last run ($last_pos) => start from beginning.\n";
    uls_value($ts, "action", "file has shrunk => start file from beginning", "[ ]");
    $last_pos = 0;
  }

  if ($last_pos < 0) {$last_pos = 0}

  if (seek(LOGFILE, $last_pos, 0)) {
    # Keeps error messages from alert file until sent to ULS.
    my @ORA = ();

    # Holds the last found timestamp in alert.log
    # must be like: 2020-03-04T08:28:54...
    my $last_ts = "";

    my $line_count = 0;
    my $error_count = 0;

    # Is set to 1, if text expressions are found in a line, 
    # which do not generate ORA- entries (Corrupt block, Process * died)
    # The next 8 lines will be accumulated in @ORA.
    my $text_errors = 0;

    while(my $L = <LOGFILE>) {

      # Management of incomplete lines:
      # Check, if the last char is a newline, if not
      # assume that it has reached the premature end-of-file.
      # Stop the loop and try next run to get further.
      # We read the bytes => so use the last pos from end
      # of last loop iteration.

      if ($L =~ /\n$/) {
        # print "Line has backslash n => continue with this line.\n"
      } else {
        print "Line has NO backslash n => ignore this line, leave while loop prematurely.\n";
        last;
      }

      # print $L;
      chomp($L);

      # Test for timestamp
      # 2020-03-04T08:28:54.684445+01:00
      if ( $L =~ /^\d\d\d\d\-\d\d\-\d\dT\d\d:\d\d:\d\d/ ) {
        # line is a time stamp, 12.1+
        $last_ts = $L;
      }

      # -----
      # Check for "ORA-"
      if ($L =~ /ORA-/) {
        if ( $L =~ /^patch description/i ) {
          print "Special Case:\n";
          print "Last timestamp: $last_ts\n";
          print "$L \n";
          print "The above line contains ORA- in conjunction with a patch description => ignored\n";
        } else {
          push(@ORA, $L);
          $error_count ++;
        }
      }

      # -----
      # Check for "Errors in file"
      if ($L =~ /Errors in file/) {
        push(@ORA, $L);
        $error_count ++;

        # Send the first 30 lines of the trace file to the ULS
        # Line looks like: "Errors in file /oracle/admin/spexp/udump/spexp_ora_17518.trc:"

        # Extract the file name
        $L =~ /Errors in file (.*):/;
        my $trc_file = $1;

        if ($trc_file) {
          if (exists($TRACE_FILES{$trc_file})) {
            print "Trace file '$trc_file' is already sent.\n";
          } else {

            if (-r $trc_file) {
              print "Reading first lines of trace file '$trc_file'...\n";

              uls_send_file_contents({
                   teststep   => $ts
                 , detail     => "first lines of trace file"
                 , filename   => $trc_file
                 , start_line => 2
                 , stop_line  => 30
                 , unit       => "_"
              });
              # start_line => 2, because the first line is the file name, which is 
              #               already the title of the file contents.
              $TRACE_FILES{$trc_file} = 1;
            } else {
              print "File '$trc_file' is not readable!\n";
            }
          }
        } else {
          print "No trace file name found!\n";
        }
      } # if "Errors in file"

      # -----
      # This adds the following lines to the @ORA
      # if there was a textual error entry found previously
      # (in a previous line)

      if ($text_errors >= 1 && $text_errors <= 8) {
        push(@ORA, $L);
        $text_errors++;
      }

      # -----
      # This message (textual error) is produced by RMAN in case of corrupt block(s):
      #
      # Corrupt block seq: 34371 blocknum=19744.
      # Bad header found during backing up archived log
      # Data in bad block - flag:1. format:34. bno:38312. seq:34369
      # beg:132 cks:14413
      # calculated check value: 14413
      # Reread of seq=34371, blocknum=19744, file=/oracle/archived_redo_..., found same corrupt data
      # ...

      if ($L =~ /Corrupt block/i) {
        push(@ORA, $L);
        $error_count++;
        $text_errors = 1;
      }

      # -----
      # This message is produced when a process died unexpectedly
      # Wed Mar 24 17:57:18 2010
      # Process m000 died, see its trace file
      # Wed Mar 24 17:57:18 2010
      # ksvcreate: Process(m000) creation failed
      # Wed Mar 24 17:58:19 2010
      # Process m000 died, see its trace file
      # Wed Mar 24 17:58:19 2010
      # ksvcreate: Process(m000) creation failed

      if ($L =~ /Process \S+ died/i) {
        push(@ORA, $L);
        $error_count++;
        $text_errors = 1;
      }


      # -----
      # Keep only the last 20 lines.
      # (If there are more than that)
      if (scalar(@ORA) > 20) {shift(@ORA)}

      $line_count ++;
      # Get my current position
      $last_pos = tell(LOGFILE);

    } # while

    # uls_value($ts, "errors", $error_count, "#");

    if ($error_count > scalar(@ORA)) {
      push(@ORA, "...");
    }
    # if ($error_count > 0) {uls_value($ts, "entry", join("\n", @ORA), "_")}
    if ($error_count > 0) {uls_value($ts, "error entry", join("\n", @ORA), "_")}

    print "$line_count lines processed in file '$alert_log', $error_count errors found.\n";

    # $last_pos = tell(LOGFILE);
  } else {
    output_error_message(sub_name() . ": Error: Cannot seek to position '$last_pos' in file '$alert_log': $!");
  }

  print "position=$last_pos (in Bytes from beginning of file) for next run.\n";

  # Close the alert.log
  if (! close(LOGFILE)) {
    output_error_message(sub_name() . ": Error: Cannot close filehandle for '$alert_log': $!");
    return(0);
  }

  set_value(\$WORKFILE, sub_name(), "last_position_in_alert", $last_pos);

  send_doc($ts);

  return(1);

} # alert_log




# ===================================================================
sub get_objects_in_buffer {
  # get_objects_in_buffer(<buffer>, <block_size>);
  #
  # get_objects_in_buffer('DEFAULT', 16384);

  # TODO: Check if that needs to be changed for non-cdb environments.

  title(sub_name());

  my ($buffer, $block_size) = @_;

  my $buffer_name = "$buffer (" . sprintf("%d", $block_size / 1024) . "k)";
  # e.g. 'DEFAULT (16k)'

  title(sub_name());

  print "Objects in Buffer Cache: '$buffer_name'\n";

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  # see also:
  # 2010-01-11 Infos about BUFFER CACHEs.txt
  # Ignore objects of SYS and SYSTEM.
  # Do not distinguish partitions for objects.
  # Take only the top 20 results (ROWNUM <= 20).
  # Suppress all objects that only got one buffer block.

  # WARNING: This statement often does not terminate!!!
  # Please, do NOT use this option currently.

  my $sql = "
    variable bsz number
    exec :bsz := $block_size

    variable buf varchar2(30)
    exec :buf := '$buffer'

    variable c number
    exec :c := 1

    variable u1 varchar2(10)
    exec :u1 := 'SYS'

    variable u2 varchar2(10)
    exec :u2 := 'SYSTEM'

    SELECT
        do.owner
      , do.object_name
      , do.object_type
      , do.subobject_name
      , COUNT(*)
    FROM dba_objects do, dba_segments ds, v\$bh v, dba_tablespaces dts
      WHERE do.data_object_id = v.objd
        AND do.owner = ds.owner(+)
        AND do.owner != :u1
        AND do.owner != :u2
        AND do.object_name = ds.segment_name(+)
        AND do.object_type = ds.segment_type(+)
        -- AND do.subobject_name = ds.partition_name(+)
        AND nvl(do.subobject_name,'-') = nvl(ds.partition_name,'-')
        AND dts.tablespace_name = ds.tablespace_name
        AND dts.block_size = :bsz
        AND ds.buffer_pool = :buf
      GROUP BY do.owner, do.object_name, do.object_type, do.subobject_name
      HAVING COUNT(*) > :c
      ORDER BY 5 desc
    ;
  ";

  # OWNER   OBJECT_NAME        OBJECT_TYPE SUBOBJECT_NAME  COUNT(*)
  # ------- ------------------------------ --------------  --------
  # ARTUS   OERTLICHELAGE      TABLE                         196986
  # ARTUS   PERSONALIE         TABLE                         125828
  # ARTUS   FALL_PERSON_BEZIEH TABLE                          68950
  # ARTUS   PERSON             TABLE                          57925
  # ARTUS   SACHE              TABLE                          57491
  # 
  # OWNER    OBJECT_NAME    OBJECT_TYPE      SUBOBJECT_NAME  COUNT(*)
  # -------- -------------- ---------------- --------------- --------
  # SPXPROD  BUCHUNG        TABLE PARTITION  P4                187565
  # SPXPROD  BUINDX0        INDEX                              100918
  # SPXPROD  BUCHUNG        TABLE PARTITION  P5                 43557
  # SPXPROD  SYS_C00437186  INDEX                               35885
  # SPXPROD  BUCHUNG        TABLE PARTITION  P3                 33181

  if (! do_sql($sql)) {return(0)}

  my @LINES;

  # There are a lot of lines in the result, get only the first 20
  get_value_lines(\@LINES, $TMPOUT1, 20);


  # -----
  # Do I need the column SUBOBJECT_NAME?
  # That is mostly only needed, if the database has partitions.

  my $got_subobj_name = 0;

  foreach my $Line (@LINES) {

    my @E = split($DELIM, $Line);
    @E = map(trim($_), @E);

    my ($owner, $object_name, $object_type, $subobj_name, $blocks) = @E;
    if ($subobj_name) { $got_subobj_name = 1 }

  } # foreach


  # -----
  my @TXT = ();

  # Titles of the columns
  if ($got_subobj_name) {
    push(@TXT, "owner.object  $DELIM  object type $DELIM  subobject name $DELIM size [MB]");
  } else {
    push(@TXT, "owner.object  $DELIM  object type $DELIM  size [MB]");
  }

  my $i = 0;

  foreach my $Line (@LINES) {

    my @E = split($DELIM, $Line);
    @E = map(trim($_), @E);

    my ($owner, $object_name, $object_type, $subobj_name, $blocks) = @E;

    my $mbytes = sprintf("%0.1f", $blocks * $block_size / 1024 / 1024);

    if ($got_subobj_name) {
      push(@TXT, "$owner.$object_name  $DELIM $object_type $DELIM $subobj_name $DELIM $mbytes");
    } else {
      push(@TXT, "$owner.$object_name  $DELIM $object_type $DELIM $mbytes");
    }

    $i++;
  } # foreach

  if ($i > 0) {
    my $colalign = "LLR";
    if ($got_subobj_name) { $colalign = "LLLR" }

    my $txt = make_text_report(\@TXT, $DELIM, $colalign, 1);

    # must match $ts in 'sub buffer_cache()'
    uls_value("buffer cache:$buffer_name", "objects", $txt, "_");
  }

  # send_doc($ts);

  return(1);

} # get_objects_in_buffer



# ===================================================================
sub objects_in_buffer_cache {
  # 
  # 2010-01-11: this works at least up to Oracle 11.1.
  #
  # The DEFAULT buffer pool uses the default block size.
  # DEFAULT buffer pools with other block size must(!) exist, i
  # if tablespaces with that block size shall be created.
  # Objects created on that tablespace are automatically cached 
  # in the appropriate buffer cache matching the db_*k_cache_size.
  #
  # The KEEP and RECYCLE buffer caches are always set up with the
  # default block size.

  # TODO: Check if that needs to be changed for non-cdb environments.

  title(sub_name());

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  # -----
  # Find the used buffers, like 'DEFAULT (16k)', 'DEFAULT (8k)' or 'KEEP (8k)'

  my $sql = "
    SELECT 
        ds.buffer_pool
      , dts.block_size
    FROM dba_segments ds, dba_tablespaces dts
      WHERE dts.TABLESPACE_NAME = ds.TABLESPACE_NAME
      GROUP BY ds.buffer_pool, dts.block_size
      ORDER BY 1, 2
    ;
  ";

  # result looks like:
  #
  # BUFFER      BLOCK_SIZE
  # ----------- ----------
  # DEFAULT          16384
  # DEFAULT           8192
  # KEEP              8192

  if (! do_sql($sql)) {return(0)}

  my @LINES;
  get_value_lines(\@LINES, $TMPOUT1);

  foreach my $line (@LINES) {
    my @E = split($DELIM, $line);
    @E = map(trim($_), @E);

    my ($buffer, $block_size) = @E;

    get_objects_in_buffer($buffer, $block_size);

  } # foreach

  # send_doc($ts);

  return(1);
} # objects_in_buffer_cache


# ===================================================================
sub latches {

  # TODO: Check if that needs to be changed for non-cdb environments.

  title(sub_name());

  my $ts = "latches";

  # That's the file where the values are stored until the next run.
  my $workfile = "$WORKFILEPREFIX.latches";

  my $sql = "select name, gets, misses from v\$latch order by name;";

  if (! do_sql($sql)) {return(0)}

  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);

  my @N = get_value_list($TMPOUT1, $DELIM, 1);

  foreach my $n (@N) {
    my $g = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n, 2)) || 0;
    my $m = trim(delta_value($workfile, $TMPOUT1, $DELIM, $n, 3)) || 0;

    if (($g > 10) || ($m > 10)) {
      # Only if more than 10 events have occurred
      my @u = ();
      push(@u, "gets:$g:#");
      push(@u, "misses:$m:#");

      if (abs($g) > $VERY_SMALL) {
        push(@u, "successful:" . pround(100.0 * ($g - $m) / $g, -1) . ":%");
      }
      if (! $wz) {uls_nvalues("$ts:$n", \@u)}
    }
  } # foreach

  make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);

  send_doc($ts);

  return(1);

} # latches



# ===================================================================
sub open_cursors {

  # TODO: Check if that needs to be changed for non-cdb environments.

  title(sub_name());

  my $ts = "cursors:open cursors";

  # This was pretty slow at the first execution.
  # select 'distinct_sid', count(distinct(sid)) from v\$open_cursor;

  my $sql = "
    variable n varchar2(20)
    exec :n := 'open_cursors'

    select 'open_cursors', value from v\$parameter where lower(name) = :n;
    select 'current_open', count(*) from v\$open_cursor;
    select 'distinct_sid', count(*) from (select sid from v\$open_cursor group by sid);
    select 'max_open_sid', max(count(*)) from v\$open_cursor group by sid;
  ";

  if (! do_sql($sql)) {return(0)}

  my $oc = trim(get_value($TMPOUT1, $DELIM, 'open_cursors'));
  my $ds = trim(get_value($TMPOUT1, $DELIM, 'distinct_sid'));
  my $co = trim(get_value($TMPOUT1, $DELIM, 'current_open'));
  my $mo = trim(get_value($TMPOUT1, $DELIM, 'max_open_sid'));

  uls_value_nodup({
     teststep  => $ts
   , detail    => "open_cursors"
   , value     => $oc
   , unit      => "#"
   , elapsed   => $DEFAULT_ELAPSED
  });

  uls_value($ts, "count", $co, "#");
  uls_value($ts, "max", $mo, "#");

  # average cursors per session: $co / $ds
  if (abs($ds) > $VERY_SMALL) {
    uls_value($ts, "avg", pround($co / $ds, -1), "#");
  }

  send_doc("open cursors", $ts);

  return(1);

} # open_cursors



# ===================================================================
sub session_cached_cursors {

  # TODO: Check if that needs to be changed for non-cdb environments.

  title(sub_name());

  my $ts = "cursors:session cached cursors";

  my $sql = "
    variable n1 varchar2(30)
    exec :n1 := 'session_cached_cursors'

    variable n2 varchar2(30)
    exec :n2 := 'session cursor cache count'

    select 'session_cached_cursors', value
      from v\$parameter
      where lower(name) = :n1;

    select 'session_count', count(a.value)
      from v\$sesstat a, v\$statname b
      where a.statistic# = b.statistic#
        and b.name = :n2;

    select 'sessions_at_limit', count(a.value)
      from v\$sesstat a, v\$statname b
      where a.statistic# = b.statistic#
        and b.name = :n2
        and a.value = (select value from v\$parameter where lower(name) = :n1);

    select 'avg', avg(a.value)
      from v\$sesstat a, v\$statname b
      where a.statistic# = b.statistic#
        and b.name = :n2;
  ";

  if (! do_sql($sql)) {return(0)}

  my $scc = trim(get_value($TMPOUT1, $DELIM, 'session_cached_cursors'));
  my $ssc = trim(get_value($TMPOUT1, $DELIM, 'session_count'));
  my $sal = trim(get_value($TMPOUT1, $DELIM, 'sessions_at_limit'));
  my $avg = trim(get_value($TMPOUT1, $DELIM, 'avg'));

  uls_value_nodup({
     teststep  => $ts
   , detail    => "session_cached_cursors"
   , value     => $scc
   , unit      => "#"
   , elapsed   => $DEFAULT_ELAPSED
  });

  # Percentage of sessions that reached the limit
  if (abs($ssc) > $VERY_SMALL) {
    uls_value($ts, "sessions hit limit", pround(100.0 * $sal / $ssc, -1), "%");
  }

  uls_value($ts, "avg", pround($avg, -1), "#");

  send_doc("Session Cached Cursors", $ts);

  return(1);

} # session_cached_cursors


# -------------------------------------------------------------------
sub scheduler {

  # TODO: Check if that needs to be changed for non-cdb environments.

  title(sub_name());

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  my $ts = "scheduler";

  # That's the file where the values are stored until the next run.
  my $workfile = "$WORKFILEPREFIX.scheduler";

  # Read the last processed log_id from workfile.
  my $last_log_id = trim(get_value($workfile, $DELIM, "max_log_id", 2));
  # If not numeric, it may be the first run ever.
  if ($last_log_id !~ /\d+/) { $last_log_id = 0 }

  my $sql = "select 'max_log_id', MAX(LOG_ID) from dba_scheduler_job_log; ";

  if (! do_sql($sql)) {return(0)}

  # Remember the found log_id in the workfile.
  # (You already have the previous log_id in $last_log_id)
  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);

  my $max_log_id = trim(get_value($TMPOUT1, $DELIM, "max_log_id", 2));

  $sql = "
    variable llid number
    exec :llid := $last_log_id

    variable mlid number
    exec :mlid := $max_log_id

    select
        JOB_NAME
      , OWNER
      , OPERATION
      , to_char(LOG_DATE, 'YYYY-MM-DD HH24:MI:SS')
      , STATUS
      , USER_NAME
      from dba_scheduler_job_log
      where log_id > :llid
        and log_id <= :mlid
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my @L;

  if (get_value_lines(\@L, $TMPOUT1)) {

    foreach my $line (@L) {
      my @E = split($DELIM, $line);
      if (scalar(@E) > 1) {
        @E = map(trim($_), @E);
        my $txt = "";
        if ($E[0]) {$txt .= "JOBNAME..: $E[0]\n"}
        if ($E[1]) {$txt .= "OWNER....: $E[1]\n"}
        if ($E[5]) {$txt .= "JOB......: $E[5]\n"}
        if ($E[2]) {$txt .= "OPERATION: $E[2]\n"}
        if ($E[4]) {$txt .= "STATUS...: $E[4]\n"}

        uls_value($ts, "scheduler log", $txt, "_", $E[3]);
      }

    } # foreach

  }

  send_doc($ts);

} # scheduler


# -------------------------------------------------------------------
sub scheduler_details {

  # TODO: Check if that needs to be changed for non-cdb environments.

  title(sub_name());

  if ($ORACLE_MAJOR_VERSION < 10) {return}

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  my $sql = "";
  my $ts = "scheduler";

  my $last_dt_param = "last_datetime";
  if ( $CURRENT_PDB ) { $last_dt_param = "last_datetime_$CURRENT_PDB" }

  # Read the datetime of last processing from workfile.
  my $last_dt = $WORKFILE->val(sub_name(), $last_dt_param, "");

  if ($last_dt !~ /\d{4}/) {
    # When there are no digits in $last_dt => start 24h in the past
    $last_dt = iso_datetime(time - 24*60*60);
    print "First run for '$ts' ever.\n";
  }
  print "last processed datetime=$last_dt.\n";

  # Now
  my $curr_dt = iso_datetime();
  print "Current timestamp: $curr_dt\n";

  # Find all scheduled jobs that have finished(!) since the last run.
  # (Means, that running jobs are not visible in ULS before they have finished.)
  $sql = "
    variable lastdt varchar2(20)
    exec :lastdt := '$last_dt'

    variable currdt varchar2(20)
    exec :currdt := '$curr_dt'

    select
        JOB_NAME, OWNER, STATUS, ERROR#, 
        to_char(ACTUAL_START_DATE, 'YYYY-MM-DD HH24:MI:SS'),
        to_char(ACTUAL_START_DATE + RUN_DURATION, 'YYYY-MM-DD HH24:MI:SS'),
        EXTRACT (DAY FROM RUN_DURATION) * 86400 + 
          EXTRACT (HOUR FROM RUN_DURATION) * 3600 + 
          EXTRACT (MINUTE FROM RUN_DURATION) * 60 + 
          EXTRACT (SECOND FROM RUN_DURATION), 
        EXTRACT (DAY FROM CPU_USED) * 86400 +
          EXTRACT (HOUR FROM CPU_USED) * 3600 +
          EXTRACT (MINUTE FROM CPU_USED) * 60 +
          EXTRACT (SECOND FROM CPU_USED)
      from dba_scheduler_job_run_details
      where to_char(ACTUAL_START_DATE + RUN_DURATION, 'YYYY-MM-DD HH24:MI:SS') >  :lastdt
        and to_char(ACTUAL_START_DATE + RUN_DURATION, 'YYYY-MM-DD HH24:MI:SS') <= :currdt
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my @L;

  if (get_value_lines(\@L, $TMPOUT1)) {

    foreach my $line (@L) {
      my @E = split($DELIM, $line);

      # print "line:", join("/", @E), "\n";
      # print "scalar:", scalar(@E), "\n";

      if (scalar(@E) == 8) {
        @E = map(trim($_), @E);

        my ($jn, $ow, $st, $er, $sd, $ed, $rn, $cu) = @E;
        $jn = uc($jn);
        $ow = uc($ow);
        $st = uc($st);

        my $tstep = "$ts:" . lc($jn);
        # Remove last digits
        $tstep =~ s/\d+$//;
        # and remove last underscore
        $tstep =~ s/_$//;

        uls_value($tstep, "job name", $jn, "[ ]", $sd);
        uls_value($tstep, "owner", $ow, "[ ]", $sd);
        uls_value($tstep, "status", $st, "[ ]", $sd);
        uls_value($tstep, "error", $er, "#", $sd);

        uls_timing({teststep => $tstep, detail => "start-stop", start => $sd, timestamp => $sd});
        uls_timing({teststep => $tstep, detail => "start-stop", stop  => $ed, timestamp => $sd});

        # $rn = sprintf("%0.2f", $rn);
        uls_value($tstep, "runtime", $rn, "s", $sd);
        # $cu = sprintf("%0.3f", $cu);
        uls_value($tstep, "cpu used", $cu, "s", $sd);

      } else {
        print sub_name() . ": Warning: Improper number of resulting elements when splitting up the line!\n";
      }

    } # foreach

  }

  # -----
  # Put the current timestamp of this SQL request into temporary file
  set_value(\$WORKFILE, sub_name(), $last_dt_param, $curr_dt);

  send_doc($ts);

} # scheduler_details


# -------------------------------------------------------------------
sub jobs {

  # TODO: Check if that needs to be changed for non-cdb environments.

  # "jobs" are nearly obsolete, since one would use the "scheduler" now.
  # DBMS_JOB ist still supported for backward compatability at least in Oracle 12.1.

  title(sub_name());

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  my $ts = "jobs";

  # Used as timestamp for jobs that have never been executed
  my $NEVER = "never";

  # That's the file where the values are stored until the next run.
  my $workfile = "$WORKFILEPREFIX.jobs";

  # Remember: 
  #   WHAT is 4000 chars which is probably more than the line size!
  #   WHAT may be several lines, it may contain remarks '--' 
  #   and probably also in /* ... */
  #   So remove the possible cr and lf by using TRANSLATE.
  #
  # Ignore any jobs that haven't run for more than a month (32 days).

  my $sql = "
    variable oldest number
    exec :oldest := 32

    select
      job
     ,schema_user
     ,nvl(to_char(last_date, 'YYYY-MM-DD HH24:MI:SS'), '$NEVER') last_execution
     ,nvl(to_char(next_date, 'YYYY-MM-DD HH24:MI:SS'), '$NEVER') next_execution
     ,failures
     ,broken
     ,total_time
     ,TRANSLATE(what, 'x'||CHR(10)||CHR(13),'x')
    from dba_jobs
    where last_date > sysdate - :oldest
    order by 1
    ;
  ";

  # How about INTERVAL (varchar 200)?


  if (! do_sql($sql)) {return(0)}

  my $wz = make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM);
  # But always send all information, 
  # jobs are running independently from database bounces.

  if (! $wz) {
    # if it is not the first run ever (where the workfile has been built)

    my @JOBS = get_value_list($TMPOUT1, $DELIM, 1);

    # Find the largest number to determine the number of 
    # significant digits. I will fill them up with zeroes.

    my $significant = 0;

    foreach my $J (@JOBS) {
      if (length(trim($J)) > $significant) { $significant = length(trim($J)) }
    }
    $significant = max($significant, 5);  # take at least 5 digits (filled up with zeroes)

    foreach my $J (@JOBS) {
      my $job = trim($J);
      # Fill up with leading zeroes for correct sorting as teststep in ULS

      $job = sprintf("%0${significant}d", $job);

      my $schema = trim(get_value($TMPOUT1, $DELIM, $J, 2));

      # The command (remember: it is unwrapped to one single line in the above SQL!)
      my $what = trim(get_value($TMPOUT1, $DELIM, $J, 8));

      my $what_short = substr($what,0,25);
      # replace possible ':' with '..'
      $what_short =~ s/:/\.\./g;

      my $tstep = "$ts:$job ($schema) $what_short";
      print "$tstep\n";

      my $last_exec       = trim(get_value($TMPOUT1, $DELIM, $J, 3));
      my $last_exec_saved = trim(get_value($workfile, $DELIM, $J, 3));

      print "last_exec='$last_exec', last_exec_saved='$last_exec_saved'\n";

      if ($last_exec ne $NEVER) {
        if (($last_exec ne $last_exec_saved) && ($last_exec_saved ne "")) {
          # Assume, that this job has run since last check

          my $next_exec = trim(get_value($TMPOUT1, $DELIM, $J, 4));
          uls_value($tstep, "next execution", $next_exec, "{DT}");

          # total_time is the total elapsed time for running this job again and again.
          my $elapsed = trim(delta_value($workfile, $TMPOUT1, $DELIM, $J, 7));

          my $last_finished = iso_datetime(iso_datetime2secs($last_exec) + $elapsed);

          uls_timing({teststep => $tstep, detail => "start-stop", start => $last_exec});
          uls_timing({teststep => $tstep, detail => "start-stop", stop  => $last_finished});

          uls_value($tstep, "runtime", $elapsed, "s");

          # Number of times this job has started and failed since its last success
          my $failures = trim(get_value($TMPOUT1, $DELIM, $J, 5));
          uls_value($tstep, "failures", $failures, "#");

          # Y: no attempt is made to run this job
          # N: an attempt is made to run this job
          my $broken = uc(trim(get_value($TMPOUT1, $DELIM, $J, 6)));
          uls_value($tstep, "broken", $broken, "[ ]");

          uls_value($tstep, "what", "$schema: $what", "_");

        }

        # # This is always sent to ULS, you may want to set an isAlive on it.
        # my $last_exec_before = time - iso_datetime2secs($last_exec);
        # uls_value($tstep, "last execution before", pround($last_exec_before / 3600, -2), "h");
        # Useless data! IsAlive can e.g. be set on 'what'.

        send_doc($ts, $tstep);
      }
    } # foreach
  }

  make_value_file($TMPOUT1, $workfile, $WORKFILE_TIMESTAMP, $DELIM, 1);

} # jobs


# -------------------------------------------------------------------
sub fast_recovery_area {
  # Not available before Oracle 10
  # if ($ORACLE_VERSION !~ /^1\d/) { return(1) }
  if ($ORACLE_MAJOR_VERSION < 10) {return(1) }

  title(sub_name());

  my $ts = "fast recovery area";

  my $sql = "";

  # -----
  # Check if fast recovery area is in use

  $sql = "
    variable n1 varchar2(30)
    variable n2 varchar2(30)

    exec :n1 := 'DB_RECOVERY_FILE_DEST_SIZE'
    exec :n2 := 'DB_RECOVERY_FILE_DEST'


    select upper(name), value from v\$parameter
      where upper(name) in (:n1, :n2);
  ";

  if (! do_sql($sql)) {return(0)}

  # 'db_recovery_file_dest' could be used for RMAN backups,
  # even if flashback feature is not enabled.

  my $db_recovery_file_dest = trim(get_value($TMPOUT1, $DELIM, 'DB_RECOVERY_FILE_DEST'));
  my $db_recovery_file_dest_size = trim(get_value($TMPOUT1, $DELIM, 'DB_RECOVERY_FILE_DEST_SIZE'));

  if ($db_recovery_file_dest && $db_recovery_file_dest_size) {
    # FRA is used
  } else {
    print "FRA is not used for backups!\n";
    return(0);
  }

  # -----
  # Usage, works for all Oracle 10+ versions

  $sql = "
    select 'fra_usage'
    , name , space_limit , space_used, space_reclaimable, number_of_files
    from v\$recovery_file_dest;
  ";

  if (! do_sql($sql)) {return(0)}

  my $fra_name = trim(get_value($TMPOUT1, $DELIM, 'fra_usage', 2));
  my $fra_size = trim(get_value($TMPOUT1, $DELIM, 'fra_usage', 3));
  my $fra_used = trim(get_value($TMPOUT1, $DELIM, 'fra_usage', 4));
  my $fra_recl = trim(get_value($TMPOUT1, $DELIM, 'fra_usage', 5));
  my $fra_nof  = trim(get_value($TMPOUT1, $DELIM, 'fra_usage', 6));

  # If no name is found
  if (! $fra_name) { return(0) }

  # That is available in the ora_dbinfo report
  # uls_value_nodup({
  #    teststep  => $ts
  #  , detail    => "recovery_file_dest"
  #  , value     => $fra_name
  #  , unit      => " "
  #  , elapsed   => $DEFAULT_ELAPSED
  # });

  uls_value($ts, "size", pround($fra_size / 1024 / 1024, -1), "MB");
  uls_value($ts, "used", pround($fra_used / 1024 / 1024, -1), "MB");

  # Percentage used
  if (abs($fra_size) > $VERY_SMALL) {
    uls_value($ts, "%used", pround(100.0 / $fra_size * $fra_used, -1), "%");
  }
  uls_value($ts, "reclaimable", pround($fra_recl / 1024 / 1024, -1), "MB");
  uls_value($ts, "number of files", $fra_nof, "#");

  send_doc($ts);

} # fast_recovery_area



# -------------------------------------------------------------------
sub audit_information {

  # TODO: Check if that needs to be changed for non-cdb environments.

  # if ($ORACLE_VERSION !~ /^1\d/) { return(1) }
  if ($ORACLE_MAJOR_VERSION < 10) {return(1) }

  title(sub_name());

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  my $ts = "audit information";

  my $sql = "";

  # -----
  # Check if audit_trail is set

  $sql = "
    variable n varchar2(20)
    exec :n := 'AUDIT_TRAIL'

    select 'AUDIT_TRAIL', value from v\$parameter where upper(name) = :n;
  ";

  if (! do_sql($sql)) {return(0)}

  my $audit_trail = trim(get_value($TMPOUT1, $DELIM, 'AUDIT_TRAIL'));
  print "AUDIT_TRAIL=$audit_trail\n";

  if ($audit_trail !~ /db/i) {
    print "AUDIT_TRAIL is not set to 'db'!\n";
    return(0);
  }

  my $wf_param = "last_datetime";
  if ( $CURRENT_PDB ) { $wf_param = "last_datetime_$CURRENT_PDB"; }

  my $last_dt = $WORKFILE->val(sub_name(), $wf_param, "");

  if ($last_dt !~ /\d{4}/) {
    # When there are no digits in $last_dt => start now
    $last_dt = iso_datetime(time - 120*24*60*60);
    print "First run for '$ts' ever.\n";
  }
  print "last processed datetime=$last_dt.\n";

  # Now
  my $curr_dt = iso_datetime();

  # returncode 0 => Action succeeded
  # other returncode indicate failure like:
  #   ORA-01017: invalid username/password; logon denied
  #   ORA-28000: the account is locked

  # select 'failed_logins', count(returncode)
  # from dba_audit_session
  # where action_name = :an
  #   and returncode > :rc
  #   and timestamp >  to_date(:lastdt, 'yyyy-mm-dd HH24:MI:SS')
  #   and timestamp <= to_date(:currdt, 'yyyy-mm-dd HH24:MI:SS')
  # ;
  # select 'successful_logins', count(returncode)
  # from dba_audit_session
  # where action_name = :an
  #   and returncode = :rc
  #   and timestamp >  to_date(:lastdt, 'yyyy-mm-dd HH24:MI:SS')
  #   and timestamp <= to_date(:currdt, 'yyyy-mm-dd HH24:MI:SS')
  # ;


  $sql = "
    variable lastdt varchar2(20)
    exec :lastdt := '$last_dt'

    variable currdt varchar2(20)
    exec :currdt := '$curr_dt'

    variable an varchar2(5)
    exec :an := 'LOGON'

    variable rc number
    exec :rc := 0

    select 'logins', 
      count(case when returncode = :rc then 1 end) as successful_logins,
      count(case when returncode > :rc then 1 end) as failed_logins
    from dba_audit_session
    where action_name = :an
      and timestamp >  to_date(:lastdt, 'yyyy-mm-dd HH24:MI:SS')
      and timestamp <= to_date(:currdt, 'yyyy-mm-dd HH24:MI:SS')
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  # successful logins
  my $successful_logins = trim(get_value($TMPOUT1, $DELIM, 'logins', 2));

  if ( $successful_logins > 0 ) {
    uls_value($ts, "successful logins", $successful_logins, "#");
  }

  # failed logins (all returncodes, means all ORA-, no distinction between ORA-1017 and ORA-28000 e.g.)
  my $failed_logins = trim(get_value($TMPOUT1, $DELIM, 'logins',3));

  if ( $failed_logins > 0 ) {

    uls_value($ts, "failed logins", $failed_logins, "#");

    # Only if this option is set in the configuration file (oracle_tools.conf)
    if ($OPTIONS =~ /FAILED_LOGIN_REPORT,/) {
      # Then prepare a report of who has tried to login from where.

      # Remember: you cannot define variables of type DATE
      # Backslashes are converted to dots.
      $sql = "
        variable lastdt varchar2(20)
        exec :lastdt := '$last_dt'

        variable currdt varchar2(20)
        exec :currdt := '$curr_dt'

        variable an varchar2(5)
        exec :an := 'LOGON'

        variable rc number
        exec :rc := 0

        select 
            to_char(timestamp,'yyyy-mm-dd HH24:MI:SS')
          , os_username
          , userhost
          , username
          , returncode
        from dba_audit_session
        where action_name = :an
          and returncode > :rc
          and timestamp >  to_date(:lastdt, 'yyyy-mm-dd HH24:MI:SS')
          and timestamp <= to_date(:currdt, 'yyyy-mm-dd HH24:MI:SS')
        order by 1,2,3
        ;
      ";
  
      if (! do_sql($sql)) {return(0)}

      my @L;

      if (get_value_lines(\@L, $TMPOUT1)) {
        # unshift(@L, "OS_USERNAME $DELIM USERNAME $DELIM USERHOST $DELIM TIMESTAMP");
        unshift(@L, "TIMESTAMP $DELIM OS USERNAME $DELIM USER HOST $DELIM DB USERNAME $DELIM RETURNCODE");

        my $txt = make_text_report(\@L, $DELIM, "LLLLL", 1);

        # The resulting text report may be too long for a simple text value.
        #
        # uls_value($ts, "failed login report", $txt, "_");
        # 
        # So use a file instead:

        if (write2file($FAILED_LOGIN_REPORT, $txt) ) {
          uls_file({
            teststep => $ts
           ,detail   => "failed login report"
           ,filename => $FAILED_LOGIN_REPORT
           ,rename_to => "failed_login_report.txt"
          });
        }
      }
    } # set as OPTION
  } # if failed logins

  send_doc($ts);


  # -----
  # Put the current timestamp of this SQL request into temporary file
  set_value(\$WORKFILE, sub_name(), $wf_param, $curr_dt);

} # audit_information


# -------------------------------------------------------------------
sub unified_audit_information {

  # TODO: Check if that needs to be changed for non-cdb environments.

  # if ($ORACLE_VERSION !~ /^1\d/) { return(1) }
  if ($ORACLE_MAJOR_VERSION < 12) {return(1) }

  title(sub_name());

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  my $ts = "unified audit information";

  my $sql = "";

  # -----
  # Check if unified_audit_trail is set

  $sql = "
    variable p varchar2(20)
    exec :p := 'unified auditing'

    select 'UNIFIED_AUDITING', value from v\$option where lower(PARAMETER) = :p;
  ";

  if (! do_sql($sql)) {return(0)}

  my $unified_audit_trail = trim(get_value($TMPOUT1, $DELIM, 'UNIFIED_AUDITING'));
  print "UNIFIED_AUDITING=$unified_audit_trail\n";

  if ($unified_audit_trail !~ /true/i) {
    print "UNIFIED_AUDITING is not activated!\n";
    return(0);
  }

  # -----
  # Check if audit_trail is set to DB

  $sql = "
    variable n varchar2(20)
    exec :n := 'AUDIT_TRAIL'

    select 'AUDIT_TRAIL', value from v\$parameter where upper(name) = :n;
  ";

  if (! do_sql($sql)) {return(0)}
  my $audit_trail = trim(get_value($TMPOUT1, $DELIM, 'AUDIT_TRAIL'));
  print "AUDIT_TRAIL=$audit_trail\n";

  if ($audit_trail !~ /db/i) {
    print "AUDIT_TRAIL is not set to 'db'!\n";
    return(0);
  }

  my $wf_param = "last_datetime";
  if ( $CURRENT_PDB ) { $wf_param = "last_datetime_$CURRENT_PDB" }

  my $last_dt = $WORKFILE->val(sub_name(), $wf_param, "");

  if ($last_dt !~ /\d{4}/) {
    # When there are no digits in $last_dt => start now
    $last_dt = iso_datetime(time - 120*24*60*60);
    print "First run for '$ts' ever.\n";
  }
  print "last processed datetime=$last_dt.\n";

  # Now
  my $curr_dt = iso_datetime();

  # return_code 0 => Action succeeded
  # other return_code indicate failure like:
  #   ORA-01017: invalid username/password; logon denied
  #   ORA-28000: the account is locked

  $sql = "
    exec SYS.DBMS_AUDIT_MGMT.FLUSH_UNIFIED_AUDIT_TRAIL;

    variable lastdt varchar2(20)
    exec :lastdt := '$last_dt'

    variable currdt varchar2(20)
    exec :currdt := '$curr_dt'

    variable an varchar2(5)
    exec :an := 'LOGON'

    variable rc number
    exec :rc := 0

    variable at varchar2(20)
    exec :at := 'standard'

    select 'logins',
      count(case when return_code = :rc then 1 end) as successful_logins,
      count(case when return_code > :rc then 1 end) as failed_logins
    from unified_audit_trail
    where action_name = :an
      and lower(AUDIT_TYPE) = :at
      and EVENT_TIMESTAMP >  to_date(:lastdt, 'yyyy-mm-dd HH24:MI:SS')
      and EVENT_TIMESTAMP <= to_date(:currdt, 'yyyy-mm-dd HH24:MI:SS')
    ;
  ";

  if (! do_sql($sql)) {return(0)}
  # successful logins
  my $successful_logins = trim(get_value($TMPOUT1, $DELIM, 'logins', 2));

  if ( $successful_logins > 0 ) {
    uls_value($ts, "successful logins", $successful_logins, "#");
  }

  # failed logins (all returncodes, means all ORA-, no distinction between ORA-1017 and ORA-28000 e.g.)
  my $failed_logins = trim(get_value($TMPOUT1, $DELIM, 'logins',3));

  if ( $failed_logins > 0 ) {

    uls_value($ts, "failed logins", $failed_logins, "#");

    # Only if this option is set in the configuration file (oracle_tools.conf)
    if ($OPTIONS =~ /FAILED_LOGIN_REPORT,/) {
      # Then prepare a report of who has tried to login from where.

      # Remember: you cannot define variables of type DATE
      # Backslashes are converted to dots.
      $sql = "
        variable lastdt varchar2(20)
        exec :lastdt := '$last_dt'

        variable currdt varchar2(20)
        exec :currdt := '$curr_dt'

        variable an varchar2(5)
        exec :an := 'LOGON'

        variable rc number
        exec :rc := 0

        variable at varchar2(20)
        exec :at := 'standard'

        select
            to_char(EVENT_TIMESTAMP,'yyyy-mm-dd HH24:MI:SS')
          , os_username
          , userhost
          , DBUSERNAME
          , RETURN_CODE
        from unified_audit_trail
        where action_name = :an
          and lower(AUDIT_TYPE) = :at
          and return_code > :rc
          and EVENT_TIMESTAMP >  to_date(:lastdt, 'yyyy-mm-dd HH24:MI:SS')
          and EVENT_TIMESTAMP <= to_date(:currdt, 'yyyy-mm-dd HH24:MI:SS')
        order by 1,2,3
        ;
      ";

      if (! do_sql($sql)) {return(0)}
      my @L;

      if (get_value_lines(\@L, $TMPOUT1)) {
        unshift(@L, "TIMESTAMP $DELIM OS USERNAME $DELIM USER HOST $DELIM DB USERNAME $DELIM RETURN CODE");

        my $txt = make_text_report(\@L, $DELIM, "LLLLL", 1);

        # The resulting text report may be too long for a simple text value.
        #
        # uls_value($ts, "failed login report", $txt, "_");
        #
        # So use a file instead:

        if (write2file($FAILED_LOGIN_REPORT, $txt) ) {
          uls_file({
            teststep => $ts
           ,detail   => "failed login report"
           ,filename => $FAILED_LOGIN_REPORT
           ,rename_to => "failed_login_report.txt"
          });
        }
      }
    } # set as OPTION
  } # if failed logins

  send_doc($ts);

  # -----
  # Put the current timestamp of this SQL request into temporary file
  set_value(\$WORKFILE, sub_name(), $wf_param, $curr_dt);

} # unified_audit_information



# -------------------------------------------------------------------
sub flashback {

  # TODO: Check if that needs to be changed for non-cdb environments.

  # Not available before Oracle 10
  # if ($ORACLE_VERSION !~ /^1\d/) { return(1) }
  if ($ORACLE_MAJOR_VERSION < 10) {return(1) }

  title(sub_name());

  my $ts = "flashback";

  # You may also want to have the "flashback log writes"
  # from the system statistics. 

  my $sql = "";

  # -----
  # Check if FLASHBACK feature is enabled in database

  $sql = "select 'flashback_on', FLASHBACK_ON from v\$database;";

  if (! do_sql($sql)) {return(0)}

  send_doc($ts);

  # -----
  my $flashback_on = trim(get_value($TMPOUT1, $DELIM, 'flashback_on'));
  print "FLASHBACK FEATURE IS: $flashback_on\n";

  # -----
  # Exit, if flashback feature is not enabled
  if (uc($flashback_on) eq "NO") {return()}

  # -----
  # Send to ULS only if enabled.

  uls_value_nodup({
     teststep  => $ts
   , detail    => "enabled"
   , value     => $flashback_on
   , unit      => "[ ]"
   , elapsed   => $DEFAULT_ELAPSED
  });

  # -----
  # Special system statistics for flashback
  #
  # Values are already found in the system statistics,
  # but currently not extracted.
  #   physical reads for flashback new
  #   flashback log writes

  # -----
  # V$FLASHBACK_DATABASE_LOG:
  #
  # OLDEST_FLASHBACK_SCN     Lowest system change number (SCN) in the flashback data
  # OLDEST_FLASHBACK_TIME    Time of the lowest SCN in the flashback data
  # RETENTION_TARGET         Target retention time (in minutes)
  # FLASHBACK_SIZE           Current size (in bytes) of the flashback data
  # ESTIMATED_FLASHBACK_SIZE Estimated size of flashback data needed for the current target retention

  $sql = "
    select 
      'flashback_database_log'
      ,to_char(OLDEST_FLASHBACK_TIME, 'YYYY-MM-DD HH24:MI:SS')
      ,RETENTION_TARGET
      ,FLASHBACK_SIZE
      ,ESTIMATED_FLASHBACK_SIZE
     from V\$FLASHBACK_DATABASE_LOG;
  ";

  if (! do_sql($sql)) {return(0)}

  my $oldest_fbt = trim(get_value($TMPOUT1, $DELIM, 'flashback_database_log', 2));
  my $ret_target = trim(get_value($TMPOUT1, $DELIM, 'flashback_database_log', 3));
  my $fb_size    = trim(get_value($TMPOUT1, $DELIM, 'flashback_database_log', 4));
  # is the same as "used" above.

  uls_value($ts, "oldest flashback timestamp", $oldest_fbt, "{DT}");
  uls_value($ts, "retention target", $ret_target, "min");

  # if ($ORACLE_VERSION =~ /^10\.1/) {
  if ($ORACLE_MAJOR_VERSION == 10 && $ORACLE_MINOR_VERSION == 1 ) {

    # No more specific info available
  } else {
    # Oracle 10.2 and newer

    $sql = "
      SELECT
        rau.file_type,
        rfd.space_used * rau.percent_space_used / 1024 / 1024 as USED_MB,
        rfd.space_reclaimable * rau.percent_space_reclaimable / 1024 / 1024 as RECLAIMABLE_MB,
        rau.number_of_files as NUMBER_OF_FILES
      FROM v\$recovery_file_dest rfd, v\$flash_recovery_area_usage rau;
    ";

    # FILE_TYPE       USED_MB RECLAIMABLE_MB NUMBER_OF_FILES
    # ------------ ---------- -------------- ---------------
    # CONTROLFILE        78,6              0               1
    # ONLINELOG       1566,76              0               6
    # ARCHIVELOG      1027,04              0               5
    # BACKUPPIECE           0              0               0
    # IMAGECOPY             0              0               0
    # FLASHBACKLOG          0              0               0

    # Does one need this?
    # Then add the commands.
  }

} # flashback


# -------------------------------------------------------------------
sub undo_usage {
  # undo_usage(<teststep>, <tablespace_name>)

  # TODO: Check if that needs to be changed for non-cdb environments.

  title(sub_name());

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  my ($tstep, $tspace) = @_;

  # http://blog.mydream.com.hk/howto/how-to-determine-undo-usage-in-oracle
  #
  # Overall usage (ACTIVE, EXPIRED, UNEXPIRED):
  # 
  # select 
  # tablespace_name, 
  # status, 
  # sum(blocks) * 8192/1024/1024/1024 GB 
  # from dba_undo_extents 
  # group by tablespace_name, status;
  # 
  # TABLESPACE_NAME                STATUS            GB
  # ------------------------------ --------- ----------
  # UNDO                           UNEXPIRED 2,85479736
  # 
  # oder auf einem anderen Rechner
  # 
  # TABLESPACE_NAME                STATUS            GB
  # ------------------------------ --------- ----------
  # UNDO                           EXPIRED   ,084777832
  # UNDO                           UNEXPIRED ,015808105
  # 
  # select
  # tablespace_name,
  # status,
  # -- sum(blocks) * 8192/1024/1024/1024 GB
  # sum(bytes) /1024/1024/1024 GB
  # from dba_undo_extents
  # group by tablespace_name, status;
  # 
  # 
  # TABLESPACE_NAME                STATUS            GB
  # ------------------------------ --------- ----------
  # UNDO                           EXPIRED   4.43341064
  # UNDO                           ACTIVE      .0078125
  # UNDO                           UNEXPIRED 6.17333984


  my $sql = "
    variable ts VARCHAR2(30)
    exec :ts := upper('$tspace')

    select
      status,
      sum(bytes)
    from dba_undo_extents
    where upper(tablespace_name) = :ts
    group by status;
  ";

  if (! do_sql($sql)) {return(0)}

  my @R;
  get_value_lines(\@R, $TMPOUT1);

  foreach my $r (@R) {
    my @E = split($DELIM, $r);
    @E = map(trim($_), @E);

    my ($status, $bytes) = @E;

    uls_value($tstep, lc($status), pround($bytes / 1024 / 1024, -1), "MB");
  } 


  # 
  # UNDO Blocks per sec
  # 
  # SELECT 
  #   MAX(undoblks/((end_time-begin_time)*3600*24)) "UNDO_BLOCK_PER_SEC"
  # FROM v$undostat;
  # 
  # UNDO_BLOCK_PER_SEC
  # ------------------
          # 5,51166667
  # 
  # UNDO_BLOCK_PER_SEC
  # ------------------
          # 195,041667
  # 




  # http://www.orafaq.com/node/61
  # 
  # Nur für LAUFENDE Transaktionen 
  # (also zB uncommited UPDATE)
  # 
  # 
  # select 
  # USED_UBLK, USED_UREC, START_SCNB
  # from v$session a, v$transaction b
  # where rawtohex(a.saddr) = rawtohex(b.ses_addr)
  # -- and a.audsid = sys_context('userenv','sessionid')
  # ;
  # 



} # undo_usage


# -------------------------------------------------------------------
sub schema_information {
  # schema_information()

  # TODO: Check if that needs to be changed for non-cdb environments.

  title(sub_name());

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  my $tstep = "schema information";

  # in MB
  my $sql = "";

  if ($ORACLE_MAJOR_VERSION >= 12) {
    # 12.1 and later
    $sql = "
      variable om char(1)
      exec :om := 'N'

      select  username, round(nvl( sum(bytes)  , 0)/1024/1024, 0)
      from dba_segments, dba_users
      where ORACLE_MAINTAINED = :om
        and username = owner (+)
      group by username;
    ";
  } else {
    # up to 11.2
    $sql = "
      variable t0off number
      exec :t0off := 2/24

      select  username, round(nvl( sum(bytes)  , 0)/1024/1024, 0)
      from dba_segments, dba_users 
      where username not in (select SCHEMA_NAME from v\$sysaux_occupants)
        and username not in (select schema from dba_registry)
        and username not in (select username from dba_users where created < (select min(created) + :t0off from dba_users))
        and username = owner (+)
      group by username;

    ";
  }

  if (! do_sql($sql)) {return(0)}

  my @R;
  get_value_lines(\@R, $TMPOUT1);

  foreach my $r (@R) {
    my @E = split($DELIM, $r);
    @E = map(trim($_), @E);

    my ($owner, $mb) = @E;

    uls_value("$tstep:$owner", "allocated space", $mb, "MB");
    send_doc($tstep, "$tstep:$owner");
  }


  # More:
  #   number of objects
  #   time until password expires
  #   ...

} # schema_information



# -------------------------------------------------------------------
sub admin_db_user {
  # admin_db_user()

  # TODO: Check if that needs to be changed for non-cdb environments.

  title(sub_name());

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  my $tstep = "administrative database user";
  # ignoring the oracle maintained users

  my $sql = "";

  # select * from (
  #   select * from dba_role_privs where GRANTED_ROLE = 'DBA' and COMMON != 'YES'
  #   union
  #   select * from sys.dba_role_privs where ADMIN_OPTION = 'YES' and COMMON != 'YES'
  # )
  # where 1 = 1
  # and GRANTEE != 'DBA'
  # and GRANTEE != 'SYS';
  # 
  # 
  # UNLIMITED TABLESPACE
  # DBA
  # RESOURCE
  # 
  # SYSDBA
  # Ab Oracle 12.1:
  # select pw.USERNAME, SYSDBA, SYSOPER, SYSASM, SYSBACKUP, SYSDG, SYSKM from v$pwfile_users pw
  #   inner join dba_users du on pw.username = du.username
  # where du.oracle_maintained != 'Y';
  # 
  # Oracle 11.2:
  # select USERNAME, SYSDBA, SYSOPER, SYSASM from v$pwfile_users; 
  # 

  if ($ORACLE_VERSION_3D lt "012.001.000.002" ) { return(0) }
  # Column DELEGATE_OPTION does not exist in versions before 12.1.0.2
  # COMMON does not exist in versions before 12.1.0.1

  $sql = "
    variable gr VARCHAR2(10)
    exec :gr := 'DBA'

    variable yes VARCHAR2(10)
    exec :yes := 'YES'

    variable g1 VARCHAR2(10)
    exec :g1 := 'DBA'

    variable g2 VARCHAR2(10)
    exec :g2 := 'SYS'

    select GRANTEE, GRANTED_ROLE, ADMIN_OPTION, DELEGATE_OPTION, DEFAULT_ROLE from (
     select * from dba_role_privs where GRANTED_ROLE = :gr  and COMMON != :yes
     union
     select * from dba_role_privs where ADMIN_OPTION = :yes and COMMON != :yes
    )
    where GRANTEE != :g1 and GRANTEE != :g2
    ;
  ";


  if (! do_sql($sql)) {return(0)}

  my @R;

  if (get_value_lines(\@R, $TMPOUT1)) {

    uls_value($tstep, "administrative database user", $#R + 1, '#');
    # Remember: $#R returns the max index of the array, which starts at zero!

    unshift(@R, "GRANTEE $DELIM GRANTED ROLE $DELIM ADMIN OPTION $DELIM DELEGATE OPTION $DELIM DEFAULT ROLE");

    my $txt = make_text_report(\@R, $DELIM, "LLLLL", 1);

    # The resulting text report may be too long for a simple text value.
    #
    # uls_value($ts, "administrative database user report", $txt, "_");
    #
    # So use a file instead:

    if (write2file($ADMIN_DBUSER_REPORT, $txt) ) {
      uls_file({
        teststep => $tstep
       ,detail   => "administrative database user report"
       ,filename => $ADMIN_DBUSER_REPORT
       ,rename_to => "administrative_database_user_report.txt"
      });
    }
  } else {
    uls_value($tstep, "administrative database user", 0, '#');
  }

  send_doc($tstep);

} # admin_db_user



# -------------------------------------------------------------------
sub tnsping {
  # tnsping();
  #
  # Execute a 
  # tnsping SID
  # and check the output for TNS- error messages.
  # Send only to ULS if an error occurs.

  # This is not for PDBs, only for Non-CDBs or the CDB.

  title(sub_name());

  my $tstep = "tnsping";

  my $cmd = "tnsping " . $ENV{"ORACLE_SID"};

  my $out = `$cmd`;

  my $xval = $?;
  if ($xval == -1) {
    # <cmd> may not be available
    output_error_message(sub_name() . ": ERROR: failed to execute command '$cmd', exit value is: $xval: $!");
    return(undef);

  } elsif ($xval & 127) {
    my $died_with = $xval & 127;
    my $coredump = ($? & 128) ? 'yes' : 'no';
    output_error_message(sub_name() . ": ERROR: child died with signal $died_with, coredump: $coredump");
    return(undef);

  } elsif ($xval != 0) {
    # Command was executed correctly, but has TNS- errors.
    # The exit value is 1.

    # output_error_message(sub_name() . ": ERROR: failed to execute command '$cmd', exit value is: $xval: $!");

    uls_value($tstep, "output", "\$ $cmd\n$out", "_");
  } else {
    # OK, proper execution
    print "Command '$cmd' exited successful with value ", $xval >> 8, "\n";
    # Do not send anything to ULS if successful.
  }

} # tnsping

# -------------------------------------------------------------------
sub pdb_service_test {
  # pdb_service_test();
  #
  # Execute a
  # tnsping <ip>:<port>/<pdb_service_name>
  # and check the output for TNS- error messages.
  # Send only to ULS if an error occurs.

  # This is only for PDBs

  title(sub_name());

  my $tstep = "pdb service test";
  my $xval;

  # my $cmd = "tnsping " . $ENV{"ORACLE_SID"};
  my $cmd = "lsnrctl status listener_" . $ENV{"ORACLE_SID"};

  my $out = `$cmd`;

  $xval = $?;
  if ($xval == -1) {
    # <cmd> may not be available
    output_error_message(sub_name() . ": ERROR: failed to execute command '$cmd', exit value is: $xval: $!");
    return(undef);

  } elsif ($xval & 127) {
    my $died_with = $xval & 127;
    my $coredump = ($? & 128) ? 'yes' : 'no';
    output_error_message(sub_name() . ": ERROR: child died with signal $died_with, coredump: $coredump");
    return(undef);

  } elsif ($xval != 0) {
    # Command was executed correctly, but has TNS- errors.
    # The exit value is 1.

    output_error_message(sub_name() . ": ERROR: failed to execute command '$cmd', exit value is: $xval: $!");

  } else {
    # OK, proper execution
    print "Command '$cmd' exited successful with value ", $xval >> 8, "\n";
    # Do not send anything to ULS if successful.
  }

  # print "$out\n";

  # (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=10.61.52.57)(PORT=6543)))
  # -----
  # Get ip address

  $out =~ /\(HOST\s*=\s*(\S+?)\s*\)\s*\(PORT\s*=\s*(\S+?)\s*\)/;
  my $host = $1;
  # For testing the name resolution only:
  # my $host = "legb2td001";
  my $port = $2;
  my $ip = $host;

  # print "host=$host, port=$port\n";

  if ($host =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) {
    # It is already an ip address
  } else {
    # getent hosts <hostname>
    # 10.61.52.56     legb2td001.dpaorinp.de legb2td001

    my $getent = `getent hosts $host`;
    chomp($getent);
    # print "getent=$getent\n";

    ($ip) = split(/\s/, $getent);
  }

  print "ip=$ip, port=$port\n";

  # -----
  $cmd = "tnsping $ip:$port/$CURRENT_PDB";

  $out = `$cmd`;
  $xval = $?;
  if ($xval == -1) {
    # <cmd> may not be available
    output_error_message(sub_name() . ": ERROR: failed to execute command '$cmd', exit value is: $xval: $!");
    return(undef);

  } elsif ($xval & 127) {
    my $died_with = $xval & 127;
    my $coredump = ($? & 128) ? 'yes' : 'no';
    output_error_message(sub_name() . ": ERROR: child died with signal $died_with, coredump: $coredump");
    return(undef);

  } elsif ($xval != 0) {
    # Command was executed correctly, but has TNS- errors.
    # The exit value is 1.

    # output_error_message(sub_name() . ": ERROR: failed to execute command '$cmd', exit value is: $xval: $!");
    uls_value($tstep, "output", "\$ $cmd\n$out", "_");

  } else {
    # OK, proper execution
    print "Command '$cmd' exited successful with value ", $xval >> 8, "\n";
    # Do not send anything to ULS if successful.
  }

  send_doc($tstep);

  return(1);

} # pdb_service_test


# -------------------------------------------------------------------
sub dataguard {

  # TODO: Check if that needs to be changed for non-cdb environments.
  #       Or check other replications similar to dataguard.

  # if ($ORACLE_VERSION !~ /^1\d/) { return(1) }
  if ($ORACLE_MAJOR_VERSION < 12) {return(1) }

  title(sub_name());

  my $ts = "data guard";

  my $sql = "";

  # -----
  # Check if dataguard is active

  $sql = " select 'dataguard_active', count(*) from v\$DATAGUARD_CONFIG; ";

  if (! do_sql($sql)) {return(0)}

  my $dg_active = trim(get_value($TMPOUT1, $DELIM, 'dataguard_active'));
  print "dataguard_active=$dg_active\n";

  if (! $dg_active) {
    print "Data Guard is not activated!\n";
    if ($ONCE_A_DAY) {
      uls_value("Info", "dataguard role", $DG_ROLE, "[ ]");
    }
    return(0);
    # DG_ROLE is "NONE"
  }

  # -----
  # Data Guard is configured when arriving here.

  $sql = "
    variable dbun VARCHAR2(30)
    exec :dbun := 'DB_UNIQUE_NAME'

    select 'dest_role', dest_role, parent_dbun 
    from v\$DATAGUARD_CONFIG 
    where DB_UNIQUE_NAME = (select value from v\$parameter where upper(name) = :dbun)
    ; 
  ";

  if (! do_sql($sql)) {return(0)}

  $DG_ROLE = trim(get_value($TMPOUT1, $DELIM, 'dest_role', 2));
  my $parent_dbun = trim(get_value($TMPOUT1, $DELIM, 'dest_role', 3));

  print "DG_ROLE=$DG_ROLE\n";
  print "Parent DB Unique Name=$parent_dbun\n";
  # PRIMARY DATABASE
  # PHYSICAL STANDBY
  # FAR SYNC
  # ...

  if ($ONCE_A_DAY) {
    uls_value("Info", "dataguard role", $DG_ROLE, "[ ]");

    uls_value($ts, "dataguard role", $DG_ROLE, "[ ]");
    uls_value($ts, "parent db_unique_name", $parent_dbun, "[ ]");
  }

  # -----

  if ($DG_ROLE eq "PHYSICAL STANDBY" ) {
    # -----
    # PHYSICAL STANDBY

    $sql = "
         variable tlag VARCHAR2(30)
         variable alag VARCHAR2(30)

         exec :tlag := 'transport lag'
         exec :alag := 'apply lag'

         select name, 
                extract(day    from TO_DSINTERVAL(value)) * 24 * 60 * 60 + 
                extract(hour   from TO_DSINTERVAL(value)) * 24 * 60 + 
                extract(minute from TO_DSINTERVAL(value)) * 60 + 
                extract(second from TO_DSINTERVAL(value)),
                (sysdate - to_date(TIME_COMPUTED, 'mm/dd/yyyy HH24:MI:SS')) * 24 * 60 * 60
         from V\$DATAGUARD_STATS
         where NAME in (:tlag, :alag)
         ;
    ";

    if (! do_sql($sql)) {return(0)}

    my $transport_lag  = trim(get_value($TMPOUT1, $DELIM, 'transport lag'));
    my $transport_lag_tc  = trim(get_value($TMPOUT1, $DELIM, 'transport lag', 2));

    print "Transport lag=$transport_lag s, transport lag compute before=$transport_lag_tc s\n";

    my $apply_lag  = trim(get_value($TMPOUT1, $DELIM, 'apply lag'));
    my $apply_lag_tc  = trim(get_value($TMPOUT1, $DELIM, 'apply lag', 2));

    print "Apply lag=$apply_lag s, apply lag compute before=$apply_lag_tc s\n";

    uls_value($ts, "transport lag", $transport_lag, "s");
    uls_value($ts, "transport lag computed before", $transport_lag_tc, "s");

    uls_value($ts, "apply lag", $apply_lag, "s");
    uls_value($ts, "apply lag computed before", $apply_lag_tc, "s");

  } elsif ($DG_ROLE eq "PRIMARY DATABASE" ) {
    # -----
    # PRIMARY DATABASE

    print "$DG_ROLE has no transport or apply lag.\n";

  } else {
    # -----
    # anything else

    print "WARNING: Data Guard role '$DG_ROLE' is not supported!\n";
  }

  send_doc($ts);

} # dataguard


# -------------------------------------------------------------------
sub auto_optimizer_stats_collection {

  # Should work for non-cdb, cdb and pdbs.

  if ($ORACLE_MAJOR_VERSION < 12) {return(0) }

  title(sub_name());

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  my $ts = "auto optimizer stats collection";

  my $sql = "";

  # -----
  # Check if auto optimizer stats collection is active

  $sql = "
    variable cliname varchar2(256)
    exec :cliname := 'auto optimizer stats collection'

    SELECT 'status', STATUS FROM DBA_AUTOTASK_CLIENT
    WHERE CLIENT_NAME = :cliname
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my $status = trim(get_value($TMPOUT1, $DELIM, 'status'));

  if ($status !~ /enabled/i) {
    print "'auto optimizer stats collection' is not activated!\n";
    return(0);
  }

  # -----
  my $wf_param = "last_datetime";
  if ( $CURRENT_PDB ) { $wf_param = "last_datetime_$CURRENT_PDB" }

  my $last_dt = $WORKFILE->val(sub_name(), $wf_param, "");

  if ($last_dt !~ /\d{4}/) {
    # When there are no digits in $last_dt => start now
    $last_dt = iso_datetime(time - 120*24*60*60);
    print "First run for '$ts' ever.\n";
  }
  print "last processed datetime=$last_dt.\n";

  # Now
  my $curr_dt = iso_datetime();

  # -----
  # Get the job executions since last run of this script

  $sql = "
        variable lastdt varchar2(20)
        exec :lastdt := '$last_dt'

        variable currdt varchar2(20)
        exec :currdt := '$curr_dt'

        variable cliname varchar2(256)
        exec :cliname := 'auto optimizer stats collection'

    select window_name
    , to_char(window_start_time, 'yyyy-mm-dd HH24:MI:SS')
    , to_char(window_start_time + window_duration, 'yyyy-mm-dd HH24:MI:SS')
    , job_status
    , to_char(job_start_time, 'yyyy-mm-dd HH24:MI:SS') job_start_time
    , extract(day    from TO_DSINTERVAL(job_duration)) * 24 * 60 * 60 +
      extract(hour   from TO_DSINTERVAL(job_duration)) * 24 * 60 +
      extract(minute from TO_DSINTERVAL(job_duration)) * 60 +
      extract(second from TO_DSINTERVAL(job_duration)) JOB_DURATION
    , job_error
    , replace(job_info, 'ORA-', 'ORA - ')
    from dba_autotask_job_history
    where job_start_time >  to_date(:lastdt, 'yyyy-mm-dd HH24:MI:SS')
      and job_start_time <= to_date(:currdt, 'yyyy-mm-dd HH24:MI:SS')
    and client_name = :cliname
    ;
  ";

  if (! do_sql($sql)) {return(0)}

  my @R;
  get_value_lines(\@R, $TMPOUT1);

  foreach my $r (@R) {
    my @E = split($DELIM, $r);
    @E = map(trim($_), @E);

    # window_name | job_status | job_start_time | job_duration [s] | job_error | job_info

    my ($window_name, $window_start_time, $window_stop_time, $job_status, $job_start_time, $job_duration, $job_error, $job_info) = @E;

    uls_value($ts, "maintenance window", $window_name, "[ ]", $job_start_time);

    # uls_value($ts, "window start time", $window_start_time, "{DT}", $job_start_time);
    # uls_value($ts, "window stop time", $window_stop_time, "{DT}", $job_start_time);
    uls_timing({teststep => $ts, detail => "maintenance window start-stop", start => $window_start_time, timestamp => $job_start_time});
    uls_timing({teststep => $ts, detail => "maintenance window start-stop", stop  => $window_stop_time, timestamp => $job_start_time});

    uls_value($ts, "job status", $job_status, "[ ]", $job_start_time);
    uls_value($ts, "job duration", $job_duration, "s", $job_start_time);
    if ( $job_error != 0 ) {
      uls_value($ts, "job error", $job_error, "#", $job_error);
    }
    if ( $job_info ) {
      uls_value($ts, "job info", $job_info, "[ ]", $job_start_time);
    }

  } # foreach

  send_doc($ts);

  # -----
  # Put the current timestamp of this SQL request into temporary file
  set_value(\$WORKFILE, sub_name(), $wf_param, $curr_dt);

} # auto_optimizer_stats_collection



# -------------------------------------------------------------------
sub blocked_objects {
  # Find blocked objects (only if blocked sessions are found)

  # TODO: Check if that needs to be changed for non-cdb environments.

  title(sub_name());

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  my ($ts) = @_;

  my $sql = "";

  # -----

  $sql = "
    SELECT a.session_id, 
       a.oracle_username, 
       a.os_user_name, 
       b.owner, 
       b.object_name, 
       b.object_type, 
       DECODE(a.locked_mode, 0, '0 - NONE: lock requested but not yet obtained', 
                             1, '1 - NULL', 
                             2, '2 - ROWS_S (SS): Row Share Lock', 
                             3, '3 - ROW_X (SX): Row Exclusive Table Lock', 
                             4, '4 - SHARE (S): Share Table Lock', 
                             5, '5 - S/ROW-X (SSX): Share Row Exclusive Table Lock', 
                             6, '6 - Exclusive (X): Exclusive Table Lock') LOCKED_MODE
    FROM   v\$locked_object a, dba_objects b 
    WHERE  a.object_id = b.object_id
    ;
    ";

  if (! do_sql($sql)) {return(0)}

  # Keeps the returned lines
  my @R;

  # Default text if no no blocked objects are found.
  my $txt = "no blocked objects found";

  # Place all result lines into @R
  if ( get_value_lines(\@R, $TMPOUT1) ) {

    # session_id dbusername osusername owner object_name object_type lock_mode 
    unshift(@R, "SESSION_ID $DELIM DB USER $DELIM OS USER $DELIM OBJECT_OWNER $DELIM OBJECT_NAME $DELIM OBJECT_TYPE $DELIM LOCKED_MODE");

    $txt = make_text_report(\@R, $DELIM, "LLLLLLL", 1);
  }

  # The resulting text report may be too long for a simple text value.
  #
  # uls_value($ts, "administrative database user report", $txt, "_");
  #
  # So use a file instead:
  my $reportfile = "${WORKFILEPREFIX}.blocked_objects_report";

  if (write2file($reportfile, $txt) ) {
    my $appended_ext = try_to_compress($reportfile);
    
    uls_file({
      teststep  => "$ts"
     ,detail    => "blocked objects report"
     ,filename  => "$reportfile$appended_ext"
     ,rename_to => "blocked_objects_report.txt$appended_ext"
    });
  }

} # blocked_objects


# -------------------------------------------------------------------
sub blocking_sessions {
  # Check for blocking sessions.

  # TODO: Check if that needs to be changed for non-cdb environments.

  # if ($ORACLE_MAJOR_VERSION < 12) {return(0) }

  title(sub_name());

  if ($ORACLE_STATUS !~ /OPEN/) {
    print "Database status is not OPEN, but $ORACLE_STATUS. Cannot access the necessary views, this sub is skipped.\n";
    return(1)
  }

  my $ts = "blocking sessions";

  my $sql = "";

  # -----
  # As alternative, you may use a sql similar to:
  # 
  # SELECT s1.username || '@' || s1.machine
  #     || ' ( SID,SERIAL# =' || s1.sid || ',' s1.serial# || ' )  is blocking '
  #     || s2.username || '@' || s2.machine 
  #     || ' ( SID=' || s2.sid || ' ) ' AS blocking_status
  #     FROM v$lock l1, v$session s1, v$lock l2, v$session s2
  #     WHERE s1.sid=l1.sid AND s2.sid=l2.sid
  #     AND l1.BLOCK=1 AND l2.request > 0
  #     AND l1.id1 = l2.id1
  #     AND l1.id2 = l2.id2;
  #
  # but that sql lists ALL blocked sessions, which might be a longer list.

  # -----
  # This sql finds the final blocker of all sessions at the top of the wait chain. 
  # This is the session/process that maybe (most probably be) causing the problem.
  #
  # So that will return only one session as result.


  $sql = "
    variable p1 varchar2(10)
    exec :p1 := 'count'

    variable p2 varchar2(20)
    exec :p2 := 'blocking_session'

    variable zero0 number
    exec :zero0 := 0

    variable fbss varchar2(20)
    exec :fbss := 'VALID'

    select :p1, count(*)
    from v\$lock l1, v\$session s1, v\$lock l2, v\$session s2
    where s1.sid=l1.sid and s2.sid=l2.sid
      and l1.BLOCK=1 and l2.request > :zero0
      and l1.id1 = l2.id1
      and l2.id2 = l2.id2;

    select :p2, username, osuser, machine, sid, serial#
    from v\$session
    where sid in (
      select distinct final_blocking_session
      from v\$session where final_blocking_session_status = :fbss
    )
    ;

  ";

  if (! do_sql($sql)) {return(0)}

  # Number of blocked sessions
  my $blocked_count = trim(get_value($TMPOUT1, $DELIM, 'count'));

  # Session that is currently blocking one or many other sessions
  my $dbusername = trim(get_value($TMPOUT1, $DELIM, 'blocking_session', 2));
  my $osuser     = trim(get_value($TMPOUT1, $DELIM, 'blocking_session', 3));
  my $machine    = trim(get_value($TMPOUT1, $DELIM, 'blocking_session', 4));
  my $sid        = trim(get_value($TMPOUT1, $DELIM, 'blocking_session', 5));
  my $serial     = trim(get_value($TMPOUT1, $DELIM, 'blocking_session', 6));

  if ($blocked_count) {

    uls_value($ts, "count", $blocked_count, '#');

    # Perhaps, you may not want to include the username/osuser
    # uls_value($ts, "blocking session", "OSUSER:${osuser} / MACHINE:${machine} / DBUSER:$dbusername / SID,SERIAL#:$sid,$serial", '[ ]');
    uls_value($ts, "blocking session", "${osuser} @ ${machine} / $dbusername / SID,SERIAL#: $sid,$serial", '[ ]');

    # blocked_objects($ts);

  } else {
    print "No blocking sessions found.\n";
    # uls_value($ts, "count", 0, '#');
  }

  send_doc($ts);

} # blocking_sessions


# ===================================================================
# main
# ===================================================================
#
# initial customization, no output should happen before this.
# The environment must be set up already.

# $CURRPROG = basename($0, ".pl");   # extension is removed
$CURRPROG = basename($0);
$IDENTIFIER = "_" . basename($0, ".pl");

my $currdir = dirname($0);
my $start_secs = time;

my $initdir = $ENV{"TMP"} || $ENV{"TEMP"} || $currdir;
my $initial_logfile = "${initdir}/${CURRPROG}_$$.tmp";
# print "initial_logfile=$initial_logfile\n";

# re-direct stdout and stderr to a temporary logfile.
open(STDOUT, "> $initial_logfile") or die "Cannot re-direct STDOUT to $initial_logfile.\n";
open(STDERR, ">&STDOUT") or die "Cannot re-direct STDERR to STDOUT.\n";
select(STDERR);
$| = 1;
select(STDOUT);
$| = 1;           # make unbuffered

# -------------------------------------------------------------------
# From here on, STDOUT+ERR is logged.

title("Start");
print "$CURRPROG is started in directory $currdir\n";

# -------------------------------------------------------------------
# Get configuration file contents

my $cfgfile = $ARGV[0];
print "configuration file=$cfgfile\n";

# my @Sections = ( "GENERAL", "ORACLE", "ULS", "WATCH_ORACLE", "WATCH_ORACLE_PDBS");
my @Sections = ( "GENERAL", "ORACLE", "ULS", "WATCH_ORACLE");
print "Reading sections: ", join(",", @Sections), " from configuration file\n";

if (! get_config2($cfgfile, \%CFG, @Sections)) {
  print STDERR "$CURRPROG: Error: Cannot parse configuration file '$cfgfile' correctly => aborting\n";
  exit(1);
}

# Check for SID-specific .conf file
my ($name,$dir,$ext) = fileparse($cfgfile,'\..*');
# $cfgfile = "${dir}${name}_$ENV{ORACLE_SID}${ext}";
$cfgfile = "${dir}$ENV{ORACLE_SID}${ext}";

if (-r $cfgfile) {
  print "$CURRPROG: Info: ORACLE_SID-specific configuration file '$cfgfile' found => processing it.\n";

  if (! get_config2($cfgfile, \%CFG, @Sections)) {
    print STDERR "$CURRPROG: Error: Cannot parse ORACLE_SID-specific configuration file '$cfgfile' correctly => aborting\n";
    exit(1);
  }
} else {
  print "$CURRPROG: Info: ORACLE_SID-specific configuration file '$cfgfile' NOT found. Executing with defaults.\n";
}

show_hash(\%CFG, "=");
print "-----\n\n";

# Set the $options string
$OPTIONS = "";

if ($CFG{"WATCH_ORACLE.OPTIONS"}) {
  my @O = split(",", $CFG{"WATCH_ORACLE.OPTIONS"});
  @O = map(trim($_), @O);
  # Add a comma to each expression for exact matching
  $OPTIONS = join(",", @O) . ",";
  print "OPTIONS=$OPTIONS\n";
}

# ----------
# This sets the %ULS to all necessary values
# deriving from %CFG (configuration file),
# environment variables (ULS_*) and defaults.

uls_settings(\%ULS, \%CFG);

show_hash(\%ULS);

# ----------
# Check for IDENTIFIER

# Set default
$IDENTIFIER = $CFG{"WATCH_ORACLE.IDENTIFIER"} || $IDENTIFIER;
print "IDENTIFIER=$IDENTIFIER\n";
# From here on, you may use $IDENTIFIER for uniqueness

# -------------------------------------------------------------------
# environment

if ((! $ENV{"ORACLE_SID"})  && $CFG{"ORACLE.ORACLE_SID"})  {$ENV{"ORACLE_SID"}  = $CFG{"ORACLE.ORACLE_SID"}}
if ((! $ENV{"ORACLE_HOME"}) && $CFG{"ORACLE.ORACLE_HOME"}) {$ENV{"ORACLE_HOME"} = $CFG{"ORACLE.ORACLE_HOME"}}

if (! $ENV{"ORACLE_SID"}) {
  print STDERR "$CURRPROG: Error: ORACLE_SID is not set in the environment => aborting.\n";
  exit(1);
}
if (! $ENV{"ORACLE_HOME"}) {
  print STDERR "$CURRPROG: Error: ORACLE_HOME is not set in the environment => aborting.\n";
  exit(1);
}
print "Oracle environment variables:\n";
print "ORACLE_HOME=", $ENV{"ORACLE_HOME"}, "\n";
print "ORACLE_SID=", $ENV{"ORACLE_SID"}, "\n";
print "\n";


# -------------------------------------------------------------------
# Working directory

my $workdir = $ENV{"WORKING_DIR"} || $CFG{"GENERAL.WORKING_DIR"} || $currdir;

if ( ! (-e $workdir)) {
  print "Creating directory '$workdir' for work files.\n";
  if (! mkdir($workdir)) {
    print STDERR "$CURRPROG: Error: Cannot create directory '$workdir' => aborting!\n";
    exit(1);
  }
}

# Prefix for work files.
$WORKFILEPREFIX = "${IDENTIFIER}";
# _watch_oracle
#
# If no oracle sid is found in the workfile prefix, then append it for uniqueness.
if ($WORKFILEPREFIX !~ /$ENV{"ORACLE_SID"}/) { $WORKFILEPREFIX .= "_" . $ENV{"ORACLE_SID"} }
# _watch_oracle_orcl
#
# Prepend the path
$WORKFILEPREFIX = "${workdir}/${WORKFILEPREFIX}";
# /oracle/admin/orcl/oracle_tools/var/_watch_oracle_orcl

print "WORKFILEPREFIX=$WORKFILEPREFIX\n";

# -------------------------------------------------------------------
# Setting up a lock file to prevent more than one instance of this
# script starting simultaneously.

$LOCKFILE = "${WORKFILEPREFIX}.LOCK";
print "LOCKFILE=$LOCKFILE\n";

if (! lockfile_build($LOCKFILE)) {
  # LOCK file exists and process is still running, abort silently.
  print "Another instance of this script is still running => aborting!\n";
  exit(1);
}

# -------------------------------------------------------------------
# The final log file.

my $logfile = "$WORKFILEPREFIX.log";

move_logfile($logfile);

# re-direct stdout and stderr to a logfile.
open(STDOUT, "> $logfile") or die "Cannot re-direct STDOUT to $logfile. $!\n";
open(STDERR, ">&STDOUT") or die "Cannot re-direct STDERR to STDOUT. $!\n";
select(STDERR);
$| = 1;
select(STDOUT);
$| = 1;           # make unbuffered

# Copy initial logfile contents to current logfile.
if (-e $initial_logfile) {
  print "Contents of initial logfile '$initial_logfile':\n";
  open(INITLOG, $initial_logfile);
  while (<INITLOG>) {print}
  close(INITLOG);
  print "Removing initial log file '$initial_logfile'...";
  if (unlink($initial_logfile)) {print "Done.\n"}
  else {print "Failed.\n"}

  print "Remove possible old temporary files.\n";
  # Remove old .tmp files
  opendir(INITDIR, $initdir);
  my @files = grep(/$CURRPROG.*\.tmp/, map("$initdir/$_", readdir(INITDIR)));
  foreach my $file (@files) {
    # Modification time of file, also fractions of days.
    my $days = pround(-M $file, -1);

    if ($days > 5) {
      print "Remove '", basename($file), "', ($days days old)...";
      if (unlink($file)) {print "Done.\n"}
      else {print "Failed.\n"}
    }
  } # foreach
}

# -------------------------------------------------------------------
title("Set up ULS");

# Initialize uls with basic settings
uls_init(\%ULS);

my $d = iso_datetime($start_secs);
$d =~ s/\d{1}$/0/;

set_uls_timestamp($d);

# The section will be dynamically changed for PDBs
# (if any are present)
my $uls_section = "";

# uls_show();

# -------------------------------------------------------------------
# The real work starts here.
# ------------------------------------------------------------


# A config:ini file:
my $f = "${WORKFILEPREFIX}.runtime_values";
print "File for runtime values: $f\n";

$WORKFILE->SetFileName($f);

if (-r $f ) {
  $WORKFILE->ReadConfig();
  set_value(\$WORKFILE, "GENERAL", "last_run_startet", iso_datetime($start_secs));
} else {
  # Set LAST_RUN to an initial value.
  #                          [section]   parameter  value
  set_value(\$WORKFILE, "GENERAL", "initialized", iso_datetime($start_secs));
}

# -----
# Define some temporary file names
$TMPOUT1 = "${WORKFILEPREFIX}_1.tmp";
print "TMPOUT1=$TMPOUT1\n";

$FAILED_LOGIN_REPORT = "${WORKFILEPREFIX}.failed_login_report";
print "FAILED_LOGIN_REPORT=$FAILED_LOGIN_REPORT\n";

$ADMIN_DBUSER_REPORT = "${WORKFILEPREFIX}.administrative_database_user_report";
print "ADMIN_DBUSER_REPORT=$ADMIN_DBUSER_REPORT\n";

print "DELIM=$DELIM\n";

# For actions once a day
$ONCE_A_DAY = scheduled("${WORKFILEPREFIX}.nineoclock", "05:00");

# ----- documentation -----
# Does the documentation needs to be resent to ULS?
title("Documentation");

if ($ONCE_A_DAY) {
  # -----
  print "Send script name and module versions.\n";

  # ---- Send name of this script and its version
  uls_value($IDENTIFIER, "script name, version", "$CURRPROG, $VERSION", "[ ]");

  # ---- Send also versions of modules.
  uls_value($IDENTIFIER, "modules", "Misc $Misc::VERSION, Uls2 $Uls2::VERSION", "[ ]");

  # -----
  print "Send the documentation during this run.\n";

  # de-reference the return value to the complete hash.
  %TESTSTEP_DOC = %{doc2hash(\*DATA)};

}

# ----- sqlplus command -----
# Check, if the sqlplus command has been redefined in the configuration file.
$SQLPLUS_COMMAND = $CFG{"ORACLE.SQLPLUS_COMMAND"} || $SQLPLUS_COMMAND;
print "SQLPLUS_COMMAND=$SQLPLUS_COMMAND\n";

# ----- general info ----
if (! general_info()) {
  # Check the alert.log, even if Oracle isn't running any longer,
  # it may contain interesting info.
  alert_log();

  output_error_message("$CURRPROG: Error: A fatal error has ocurred! Aborting script.");

  clean_up($TMPOUT1, $LOCKFILE);

  send_runtime($start_secs);

  uls_flush(\%ULS);

  set_value(\$WORKFILE, "GENERAL", "last_run_finished", iso_datetime(time));
  $WORKFILE->RewriteConfig();

  exit(1);
}

# ----- administrative database users -----
if ($ONCE_A_DAY) {
  admin_db_user();
}

# ----- tablespace usage -----
tablespace_usage();

# ----- sessions and processes -----
sessions_processes();

# ----- grouped connections -----
if ($OPTIONS =~ /GROUPED_CONNECTIONS,/) {
  grouped_connections();
}

# ----- rollback segment summary -----
if ($OPTIONS =~ /ROLLBACK,/) {
  rollback_segment_summary();
}

# ----- system statistics -----
system_statistics();

# ----- sga -----
sga();

# ----- shared pool -----
shared_pool();

# ----- library caches -----
library_caches();

# ----- dictionary cache -----
dictionary_cache();

# ----- detailed dictionary cache analysis
if ($OPTIONS =~ /DETAILED_DICTIONARY_CACHE,/) {
  dictionary_cache_detailed();
}


# ----- buffer cache -----
buffer_cache();


# ----- pga -----
pga();

# ----- redo logs -----
redo_logs();

# ----- alert log -----
alert_log();

# ----- cursors, session cached cursors
if ($OPTIONS =~ /CURSORS,/) {
  open_cursors();
  session_cached_cursors();
}

# ----- wait events -----
if ($OPTIONS =~ /WAIT_EVENTS,/) {
  wait_events();
}

# ----- wait events classes -----
if ($OPTIONS =~ /WAIT_EVENT_CLASSES,/) {
  wait_event_classes();
}

# ----- number of buffers held by objects -----
# This is buggy, please do not use until fixed in later version.
#
# if ($OPTIONS =~ /BUFFER_OBJECTS,/) {
#   objects_in_buffer_cache();
# }

# ----- latches -----
if ($OPTIONS =~ /LATCHES,/) {
  latches();
}

# ----- jobs -----
if ($OPTIONS =~ /JOBS,/) {
  jobs();
}

# ----- scheduler -----
# This is replaced by scheduler_details()
#
# if ($OPTIONS =~ /SCHEDULER,/) {
#   scheduler();
# }

# ----- scheduler details -----
# This replaces the scheduler(), it has more information

if ($OPTIONS =~ /SCHEDULER,/) {
  scheduler_details();
}


# ----- fast recovery area
# if fast recovery area is used.
fast_recovery_area();


# ----- flashback -----
# Will deliver values only if flashback is enabled.
flashback();

# ----- dataguard -----
#  Will deliver values only if dataguard is configured
dataguard();

# ----- execution of 'auto optimizer stats collection' -----
auto_optimizer_stats_collection();


# ----- audit information -----

audit_information();
unified_audit_information();

# ----- schema information -----
if ($ONCE_A_DAY) {
  if ($OPTIONS =~ /SCHEMA_INFO,/) {
    schema_information();
  }
}

# ----- tnsping -----
# Check the listener
# It is NOT a complete connection

if ($OPTIONS =~ /TNSPING,/) {
  tnsping();
}

# ----- blocking sessions -----
# Check for blocking sessions

blocking_sessions();


# ==================================================================
# CDB/PDB

if ($#PDB_LIST >= 0) {
  # Remember: $#ARRAY returns the max index of the array, which starts at zero!

  print "List of PDBs and CON_IDs: ", join(",", @PDB_LIST), "\n";

  # Set the $options string
  # for watch_oracle_pdbs

  # $OPTIONS = "";
  #
  # if ($CFG{"WATCH_ORACLE_PDBS.OPTIONS"}) {
  #   my @O = split(",", $CFG{"WATCH_ORACLE_PDBS.OPTIONS"});
  #   @O = map(trim($_), @O);
  #   # Add a comma to each expression for exact matching
  #   $OPTIONS = join(",", @O) . ",";
  #   print "OPTIONS=$OPTIONS\n";
  # }

  # -----
  # Keep that, add pdb name for each pdb in loop below
  my $base_WORKFILEPREFIX = $WORKFILEPREFIX;

  foreach my $p (@PDB_LIST ) {
    # pdb_name|con_id

    ($CURRENT_PDB, $CURRENT_CON_ID) = split('\|', $p);
    print "p=$p, CURRENT_PDB=$CURRENT_PDB, CURRENT_CON_ID=$CURRENT_CON_ID\n";

    my $pdb_lc = lc($CURRENT_PDB);

    $uls_section = $CFG{"ULS.ULS_SECTION_PDB"} ;
    # ULS_SECTION_PDB = Oracle DB [%%ORACLE_SID%% -> __PDB_NAME__]
    # vi /etc/uls/oracle/standard.conf

    $uls_section =~ s/__PDB_NAME__/$pdb_lc/g;

    print "Setting ULS_SECTION to: $uls_section\n";

    set_uls_section($uls_section);

    # -----
    print "Checking pluggable database '$CURRENT_PDB'\n";

    $WORKFILEPREFIX = $base_WORKFILEPREFIX . "_$pdb_lc";
    print "WORKFILEPREFIX=$WORKFILEPREFIX\n";

    $FAILED_LOGIN_REPORT = "${WORKFILEPREFIX}.failed_login_report";
    print "FAILED_LOGIN_REPORT=$FAILED_LOGIN_REPORT\n";

    $ADMIN_DBUSER_REPORT = "${WORKFILEPREFIX}.administrative_database_user_report";
    print "ADMIN_DBUSER_REPORT=$ADMIN_DBUSER_REPORT\n";


    general_pdb_info();

    # ----- administrative database users -----
    if ($ONCE_A_DAY) {
      admin_db_user();
    }

    # ----- tablespace usage -----
    tablespace_usage();

    # ----- sessions and processes -----
    sessions_processes_pdb();

    # ----- grouped connections -----
    if ($OPTIONS =~ /GROUPED_CONNECTIONS,/) {
      grouped_connections();
    }

    # ----- system statistics -----
    system_statistics();

    # ----- consumed resources -----
    consumed_resources();

    # ----- shared pool -----
    # the pdb part is retrieved in consumed_resources()
    # shared_pool();

    # ----- library caches -----
    # This is not really relevant, so leave it out for now.
    # library_caches();

    # ----- dictionary cache -----
    # This is not really relevant, so leave it out for now.
    # dictionary_cache();

    # ----- detailed dictionary cache analysis
    # This is not really relevant, so leave it out for now.
    # if ($OPTIONS =~ /DETAILED_DICTIONARY_CACHE,/) {
    #   dictionary_cache_detailed();
    # }

    # ----- pga -----
    # the pdb part is retrieved in consumed_resources()
    # but there may be more information about pga that could be of interest.
    # TODO
    # pga();

    # ----- cursors, session cached cursors
    if ($OPTIONS =~ /CURSORS,/) {
      open_cursors();
      session_cached_cursors();
    }

    # ----- wait events -----
    if ($OPTIONS =~ /WAIT_EVENTS,/) {
      wait_events();
    }

    # ----- wait events classes -----
    if ($OPTIONS =~ /WAIT_EVENT_CLASSES,/) {
      wait_event_classes();
    }
    # ----- latches -----
    if ($OPTIONS =~ /LATCHES,/) {
      latches();
    }

    # ----- jobs -----
    if ($OPTIONS =~ /JOBS,/) {
      jobs();
    }

    # ----- scheduler details -----
    if ($OPTIONS =~ /SCHEDULER,/) {
      scheduler_details();
    }

    # ----- Check the service availability -----
    if ($OPTIONS =~ /SERVICE_CHECK,/) {
      pdb_service_test();
    }

    # ----- dataguard -----
    #  Will deliver values only if dataguard is configured
    # dataguard();

    # ----- execution of 'auto optimizer stats collection' -----
    auto_optimizer_stats_collection();


    # ----- audit information -----
    audit_information();
    unified_audit_information();

    # ----- schema information -----
    if ($ONCE_A_DAY) {
      if ($OPTIONS =~ /SCHEMA_INFO,/) {
        schema_information();
      }
    }

    # ----- blocking sessions -----
    # Check for blocking sessions

    blocking_sessions();

    ## -----
    ## Continue here with more pdb tests.

  } # foreach pdb


} # is_cdb, has pdbs


## -----
## Continue here with more tests.

# The real work ends here.
# -------------------------------------------------------------------

$uls_section = $CFG{"ULS.ULS_SECTION"} ;
# ULS_SECTION_PDB = Oracle DB [%%ORACLE_SID%%]

set_uls_section($uls_section);


# Any errors will have sent already its error messages.
uls_value($IDENTIFIER, "message", $MSG, " ");
# uls_value($IDENTIFIER, "exit value", $EXIT_VALUE, "#");

send_doc($CURRPROG, $IDENTIFIER);

send_runtime($start_secs);
# uls_timing($IDENTIFIER, "start-stop", "stop");

uls_flush(\%ULS);

# -------------------------------------------------------------------
clean_up($TMPOUT1, $FAILED_LOGIN_REPORT, $LOCKFILE);

# -----
# Save runtime values

set_value(\$WORKFILE, "GENERAL", "last_run_finished", iso_datetime(time));
$WORKFILE->RewriteConfig();

# -----
title("END");

if ($MSG eq "OK") {exit(0)}
else {exit(1)}


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

#########################
*watch_oracle.pl
===============

This is the monitoring script for Oracle 9i, 10g, 11g and 12c database instances. 

This script is part of the 'ULS Client for Oracle' and works best with the Universal Logging System (ULS). Visit the ULS homepage at http://www.universal-logging-system.org

This script may not deliver all metrics that YOU are interested in, 
especially not any RAC specifics (currently), but it gives quite 
an overview of e.g.:
  the instance status, SGA, PGA and tablespaces.
  the shared pool and the buffer pools,
  the dictionary and library caches,
  sessions, processes and database system activity.

This script is run by a calling script, typically 'oracle_instance.sh', that sets the correct environment before starting the Perl script watch_oracle.pl. The '' in turn is called by the cron daemon on Un*x or through a scheduled task on Wind*ws. The script generates log files and several work files to keep data for the next run(s). The directory defined by WORKING_DIR in the oracle_tools.conf configuration file is used as the destination for those.

You may place the scripts in whatever directory you like.

script name, version:
  Sends the name and the current version of this script.

modules:
  The name and the versions of the used self-developed Perl modules.

# start-stop:
#  The start and stop timestamps for the script.
#
documentation:
  Is 'transferring' when the complete incorporated documentation section 
  for many teststeps of this script is transferred to the ULS. By default, 
  this happens once a day.

message:
  If the script runs fine, it returns 'OK', else an error message.
  This is intended to monitor the proper execution of this script.

runtime:
  The runtime of the script. This does not include the transmission
  to the ULS.

# exit value:
#   Is 0 if the script has finished without errors, 
#   1 if errors have occurred. This is intended to monitor the 
#   proper execution of this script.
# 


Copyright 2004 - 2021, roveda

The 'ULS Client for Oracle' is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The 'ULS Client for Oracle' is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with the 'ULS Client for Oracle'.  If not, see <http://www.gnu.org/licenses/>.

#########################
*Info
====

database status:
  should be 'OPEN' for normal operation.

database available:
  is 100% if the database status is 'OPEN', else it is 0%
  This may be used to calculate service availability.

database log mode:
  is 'ARCHIVELOG' or 'NOARCHIVELOG'. You only can perform online
  backups, if the instance is in 'ARCHIVELOG' mode.

hostname:
  The hostname of the server where the instance is running.
  A possible backslash is replaced by a dot.

instance name:
  should match to the environment variable ORACLE_SID and can be get through:

instance startup at:
  is the ISO timestamp of when this instance has been started.

oracle version:
  is the version of this instance.
  select version from v$instance;

#########################
*Info PDB
====

pdb name:
  Name of the PDB.

cdb name:
  Name of the CDB.

open mode:
  Should be 'READ WRITE' for normal operation.

open time:
  Is the ISO timestamp of when this pdb has been started.

total size:
  The total size of the pdb on disk in GB.

block size:
  The default block size of the pdb.


#########################
*Cursors
=======

TODO 




#########################
*Wait Event Classes
===================

Wait events are statistics that are incremented by a server process or thread to indicate that it had to wait for an event to complete before being able to continue processing. Wait events are grouped into classes.

When a database is up and running, every connected process is either busy performing work or waiting to do so. 

The 'idle' and 'other' wait classes are ignored.

An idea of overall wait problems is presented at:
  http://www.oracle.com/technology/pub/articles/schumacher_10gwait.html
or in the appropriate "Oracle® Database Performance Tuning Guide".


total waits:
  Number of waits occurred for the specific wait class.

time waited:
  Sum of time waited for the specific wait class.

average time waited:
  Average wait time for each wait. Ratio of 'time waited' to 'total waits'.

ratio to sum total waits:
  Percentage of the wait class 'total waits' to the sum of 'total waits' 
  for all wait classes.

ratio to sum time waited:
  Percentage of the wait class 'time waited' to the sum of 'time waited' 
  for all wait classes.

#########################
*Wait Events
===========

Wait events are statistics that are incremented by a server process or thread to indicate that it had to wait for an event to complete before being able to continue processing. Wait event data reveals various symptoms of problems that might be impacting performance, such as latch contention, buffer contention, and I/O contention. Remember that these are only symptoms of problems, not the actual causes.

SQL*Net Events
  If these wait events constitute a significant portion of the wait 
  time on the system or for a user experiencing response time issues, 
  then the network or the middle-tier could be a bottleneck.

buffer busy waits
  This wait indicates that there are some buffers in the buffer cache 
  that multiple processes are attempting to access concurrently.

db file scattered read
  This event signifies that the user process is reading buffers into the 
  SGA buffer cache and is waiting for a physical I/O call to return. 
  A db file scattered read issues a scattered read to read the data into 
  multiple discontinuous memory locations. A scattered read is usually a 
  multiblock read. It can occur for a fast full scan (of an index) 
  in addition to a full table scan.

db file sequential read
  This event signifies that the user process is reading a buffer into the 
  SGA buffer cache and is waiting for a physical I/O call to return. 
  A sequential read is a single-block read.

  Single block I/Os are usually the result of using indexes. Rarely, 
  full table scan calls could get truncated to a single block call due 
  to extent boundaries, or buffers already present in the buffer cache.

enqueue waits (enq)
  Enqueues are locks that coordinate access to database resources. 
  This event indicates that the session is waiting for a lock that is 
  held by another session.

free buffer waits
  This wait event indicates that a server process was unable to find a 
  free buffer and has posted the database writer to make free buffers by 
  writing out dirty buffers. A dirty buffer is a buffer whose contents 
  have been modified. Dirty buffers are freed for reuse when DBWR has 
  written the blocks to disk.

latch events (latch)
  A latch is a low-level internal lock used by Oracle to protect memory 
  structures. The latch free event is updated when a server process 
  attempts to get a latch, and the latch is unavailable on the first attempt.


Generally, the analysis of wait events is very sophisticated, good documentation is found for the different Oracle versions at:

Oracle 10.1:
  http://download.oracle.com/docs/cd/B14117_01/server.101/b10752/instance_tune.htm#18211

Oracle 10.2:
  http://docs.oracle.com/cd/B19306_01/server.102/b14211/instance_tune.htm#i18202

Oracle 11.1:
  http://docs.oracle.com/cd/B28359_01/server.111/b28274/instance_tune.htm#PFGRF02410

Oracle 11.2:
  http://docs.oracle.com/cd/E11882_01/server.112/e41573/instance_tune.htm#PFGRF02410

Oracle 12.1:
  http://docs.oracle.com/cloud/latest/db121/TGDBA/pfgrf_instance_tune.htm#TGDBA02410

For some wait events, Oracle Note 223117.1 and 34558.1 may also be of interest.

For some values, TIMED_STATISTICS must be set to TRUE, which is not the default for some operating systems.


total waits:
  Total number of waits for the event.

total timeouts:
  Total number of timeouts for the event.

time waited:
  Total amount of time waited for the event.

average wait:
  Average amount of time waited for the event.

#########################
*SGA
===
Because the purpose of the SGA is to store data in memory for fast access, the SGA should be large but within main memory. If pages of the SGA are swapped to disk, then the data is no longer quickly accessible. On most operating systems, the disadvantage of paging significantly outweighs the advantage of a large SGA.

overall size:
  The current size of the complete SGA.
  select sum(value) from v$sga;

# free memory:
#   select current_size from v$sga_dynamic_free_memory;
# 
# You may change buffer cache, shared pool and large pool without bouncing the instance, as long as there is free memory available.

#########################
# This is left over only for Oracle 9
#
*Buffer Cache (simple)
======================

size:
Size of the buffer cache.
  select component, current_size
    from v$sga_dynamic_components
    where component = 'buffer cache';

used:
Used or occupied part of the buffer cache.
  select block_size * sum(buffers)
    from v$buffer_pool
    group by block_size;

hit ratio:
  The buffer cache hit ratio calculates how often a requested block has been
  found in the buffer cache without requiring disk access. This ratio is
  computed using data selected from the dynamic performance view V$SYSSTAT.
  The buffer cache hit ratio can be used to verify the physical I/O as predicted
  by V$DB_CACHE_ADVICE.

for Oracle 9.2:
  select name, value from v$sysstat where name in
    ('session logical reads', 'physical reads',
     'physical reads direct','physical reads direct (lob)');

                               physical reads - physical reads direct - physical reads direct (lob)
  Buffer Cache Hit Ratio = 1 - -------------------------------------------------------------------------------------
                               db block gets + consistent gets - physical reads direct - physical reads direct (lob)

  You may change the buffer cache size, if there is still free memory in the sga by issueing e.g.:
  alter system set db_cache_size = 96M;

for Oracle 10 and subsequent versions:
  SELECT NAME, VALUE FROM V$SYSSTAT WHERE NAME IN
     ('db block gets from cache', 'consistent gets from cache', 'physical reads cache');

                               physical reads cache
  Buffer Cache Hit Ratio = 1 - -----------------------------------------------------
                               consistent gets from cache + db block gets from cache

See also (Oracle 12.1): http://docs.oracle.com/database/121/TGDBA/tune_buffer_cache.htm#TGDBA533

The 'buffer cache/size' is equal to 'sga/database buffers'.


#########################
# this is used for all buffer caches (KEEP, RECYCLE, DEFAULT)
#
*Buffer Cache
============

Oracle uses the buffer cache to store blocks read from disk. By default, there is only one buffer cache defined for the default block size. Other default buffer caches using different block sizes may be defined, also a keep and a recycle buffer cache.

For more information, see the "Oracle® Database Performance Tuning Guide"

size:
  Current size of the buffer cache.

used:
  Number of currently used buffer blocks multiplied by the block size.
  This is normally just a bit smaller than 'size'.

hit ratio:
  The buffer cache hit ratio represents how often a requested block has 
  been found in the buffer cache without requiring disk access.

  SELECT physical_reads, db_block_gets + consistent_gets
    FROM V$BUFFER_POOL_STATISTICS;

  Using the above results for each buffer cache, its hit ratio
  is calculated with the following formula:

  hit ratio = 1 - (physical_reads / (db_block_gets + consistent_gets)) * 100

objects: (optional)
  This report shows the top 20 objects which have occupied the most space
  in the buffer cache.

#########################
*Shared Pool
===========
Contains the most recently used SQL statements and parse trees along with PL/SQL blocks.

size:
  The current size of the shared pool.

used:
  The currently used space in the shared pool.

free:
  The currently free space in the shared pool.

%used:
  Ratio of used to size.


Increasing the amount of memory for the shared pool increases the amount of memory available to both the library cache and the dictionary cache.

To ensure that shared SQL areas remain in the cache after their SQL statements are parsed, increase the amount of memory available to the library cache until the V$LIBRARYCACHE.RELOADS value is near zero. To increase the amount of memory available to the library cache, increase the value of the initialization parameter SHARED_POOL_SIZE.

The Reserved Pool is 5% of the shared pool by default, that limits used to 95%, except SHARED_POOL_RESERVED_SIZE is otherwise configured in the init.ora.

You may change the shared pool size, if there is still free memory in the sga by issueing e.g.:
alter system set shared_pool_size = 200M;

In newer Oracle databases, the sga_max_size is set and Oracle manages all pools by itself.

#########################
*Library Cache
=============

The library cache holds executable forms of SQL cursors, PL/SQL programs, and Java classes.

{http://www.dbasupport.com/oracle/ora10g/LibraryCache1.shtml}

The library cache is nothing more than an area in memory, specifically one of three parts inside the shared pool. The library cache is composed of shared SQL areas, PL/SQL packages and procedures, various locks and handles, and in the case of a shared server configuration, stores private SQL areas. 

Whenever an application wants to execute SQL or PL/SQL (collectively called code), that code must first reside inside Oracle's library cache. When applications run and reference code, Oracle will first search the library cache to see if that code already exists in memory. If the code already exists in memory then Oracle can reuse that existing code (also known as a soft parse). If the code does not exist, Oracle must then load the code into memory (also known as a hard parse, or library cache miss). There are various criteria as to whether code being requested actually matches code already in the library cache. 

Be aware that a configured library cache area, since it is allocated a specific amount of memory, can actively only hold so much code before it must age out some to make room for code that is required by applications. This is not necessarily a bad thing but we must be aware of the size of our library cache as well as how many misses or hard parses that are occurring. If there are too many, we may need to increase the amount of memory allocated to the library cache.

For more information, see the "Oracle® Database Performance Tuning Guide"

gets:
  The number of lookups for code in the library cache. When a statement 
  needs to be executed, the library cache is checked for a previous 
  instance of it. If found, it is one get.

gethits:
  The number of successful library cache lookups.

gethitratio:
  The ratio of gethits to gets.

pins:
  The number of executions for code in the library cache.

pinhits:

pinhitratio:
  The ratio of pinhits to pins.

reloads:
  The number of attempts to execute code but it was not found 
  in the library cache.

invalidations:
  The number of times that statements have become invalid for 
  some reason, typically through a DDL operation, and a reparse 
  is required.

#########################
*Dictionary Cache
================

The dictionary cache is part of the shared pool. Information stored in the data dictionary cache includes usernames, segment information, profile data, tablespace information, and sequence numbers. The dictionary cache also stores descriptive information, or metadata, about schema objects. Oracle uses this metadata when parsing SQL cursors or during the compilation of PL/SQL programs.

Misses on the data dictionary cache are to be expected in some cases. On instance startup, the data dictionary cache contains no data. Therefore, any SQL statement issued is likely to result in cache misses. As more data is read into the cache, the likelihood of cache misses decreases. Eventually, the database reaches a steady state, in which the most frequently used dictionary data is in the cache. At this point, very few cache misses occur.

For more information, see the "Oracle® Database Performance Tuning Guide".

gets:
  Shows the total number of requests for information on the 
  corresponding item.

getmisses:
  Shows the number of data requests which were not satisfied 
  by the cache, requiring an I/O.

fixed:
  Number of fixed entries in the cache.

modifications:
  Shows the number of times data in the dictionary cache was updated.

overall hit ratio:
  It is also possible to calculate an overall dictionary cache hit ratio
  using the following formula; however, summing up the data over all the
  caches will lose the finer granularity of data:

  select (sum(gets - getmisses - fixed)) / sum(gets) from v$rowcache;

Examine cache activity by monitoring the GETS and GETMISSES columns. For frequently accessed dictionary caches, the ratio of total GETMISSES to total GETS should be less than 10% or 15%, depending on the application.

Increase the amount of memory available to the data dictionary cache by increasing the value of the initialization parameter SHARED_POOL_SIZE (if not automatic memory management is enabled).

#########################
# this matches sub dictionary_cache_detailed
#
*Detailed Dictionary Cache
=========================

Typically, if the shared pool is adequately sized for the library cache, it will also be adequate for the dictionary cache data.

Misses on the data dictionary cache are to be expected in some cases. On instance startup, the data dictionary cache contains no data. Therefore, any SQL statement issued is likely to result in cache misses. As more data is read into the cache, the likelihood of cache misses decreases. Eventually, the database reaches a steady state, in which the most frequently used dictionary data is in the cache. At this point, very few cache misses occur.

This shows the statistics for a particular data dictionary item.

gets:
  Shows the total number of requests for information on the
  corresponding item.

getmisses:
  Shows the number of data requests which were not satisfied
  by the cache, requiring an I/O.

fixed:
  Number of fixed entries in the cache.

modifications:
  Shows the number of times data in the dictionary cache was updated.

hit ratio:
  Item-specific hit ratio.



#########################
*Processes
=========

The number of current processes. Processes include the background processes of the Oracle instance. You may check if you are running out of processes if you compare the number of current processes against the number of defined (in init.ora/spfile) number of processes (max processes).

processes:
  The number of all processes.

  select 'processes', count(*) from v\$process;

max processes:
  The defined max number of processes.

  select name, value from v$parameter where name = 'processes';

max processes since startup:
  Maximum number of processes that have been used since instance startup.

#########################
*PGA
===

The Program Global Area (PGA) is a private memory region containing data and control information for a server process. Access to it is exclusive to that server process and is read and written only by the Oracle code acting on behalf of it.

For more information, see the Oracle® Database Performance Tuning Guide.

The automatic PGA Memory Management is enabled, if the PGA_AGGREGATE_TARGET initialization parameter is set to a non-zero value. It cannot be used for shared server connections!


aggregate PGA target parameter:
  This is the current value of the initialization parameter 
  PGA_AGGREGATE_TARGET. If you do not set this parameter, its value 
  is 0 and automatic management of the PGA memory is disabled.

aggregate PGA auto target:
  This gives the amount of PGA memory Oracle can use for work areas 
  running in automatic mode. This amount is dynamically derived from 
  the value of the parameter PGA_AGGREGATE_TARGET and the current work 
  area workload. Hence, it is continuously adjusted by Oracle. If this 
  value is small compared to the value of PGA_AGGREGATE_TARGET, then a 
  lot of PGA memory is used by other components of the system (for 
  example, PL/SQL or Java memory) and little is left for sort work areas. 
  You must ensure that enough PGA memory is left for work areas running 
  in automatic mode.

global memory bound:
  This gives the maximum size of a work area executed in AUTO mode. This 
  value is continuously adjusted by Oracle to reflect the current state 
  of the work area workload. The global memory bound generally decreases 
  when the number of active work areas is increasing in the system. As a 
  rule of thumb, the value of the global bound should not decrease to less 
  than one megabyte. If it does, then the value of PGA_AGGREGATE_TARGET 
  should probably be increased.

total PGA allocated:
  This gives the current amount of PGA memory allocated by the instance. 
  Oracle tries to keep this number less than the value of PGA_AGGREGATE_TARGET. 
  However, it is possible for the PGA allocated to exceed that value by a 
  small percentage and for a short period of time, when the work area workload 
  is increasing very rapidly or when the initialization parameter 
  PGA_AGGREGATE_TARGET is set to a too small value.

total PGA used for auto workareas:
  This indicates how much PGA memory is currently consumed by work areas 
  running under automatic memory management mode. This number can be used 
  to determine how much memory is consumed by other consumers of the PGA 
  memory (for example, PL/SQL or Java):

  PGA other = total PGA allocated - total PGA used for auto workareas

maximum PGA allocated:
  This is the maximum amount of PGA memory allocated since instance start.

over allocation count:
  Over-allocating PGA memory can happen if the value of PGA_AGGREGATE_TARGET 
  is too small to accommodate the PGA other component in the previous equation 
  plus the minimum memory required to execute the work area workload. 
  When this happens, Oracle cannot honor the initialization parameter 
  PGA_AGGREGATE_TARGET, and extra PGA memory needs to be allocated. If 
  over-allocation occurs, you should increase the value of 
  PGA_AGGREGATE_TARGET (=> V$PGA_TARGET_ADVICE).

total bytes processed:
  This is the number of bytes processed by memory-intensive SQL operators. 
  For example, the number of byte processed is the input size for a sort 
  operation.

extra bytes read/written:
  When a work area cannot run optimally, one or more extra passes is 
  performed over the input data. extra bytes read/written represents the 
  number of bytes processed during these extra passes since instance 
  start-up. This number is also used to compute the cache hit percentage.

cache hit ratio:
  This metric is computed by Oracle to reflect the performance of the PGA 
  memory component. A value of 100% means that all work areas executed by 
  the system have used an optimal amount of PGA memory. Some work areas 
  run one-pass or even multi-pass, depending on the overall size of the PGA 
  memory (=> system statistics). When a work area cannot run optimally, one 
  or more extra passes is performed over the input data. This reduces the 
  cache hit percentage in proportion to the size of the input data and the 
  number of extra passes performed.

                    total bytes processed * 100
  cache hit ratio = ------------------------------------------------
                    total bytes processed + extra bytes read/written

#########################
*Redo Logs
=========

The most crucial structure for recovery operations is the redo log, which consists of two or more preallocated files that store all changes made to the database as they occur. Every instance of an Oracle Database has an associated redo log to protect the database in case of an instance failure.

For more information, see the Oracle® Database Administrator´s Guide.

redo buffer allocation retries:
  Total number of retries a user process must wait to allocate space in the
  redo buffer. Retries are needed either because the redo writer has fallen
  behind or because an event such as a log switch is occurring.

  The value of redo buffer allocation retries should be near zero over an
  interval. If this value increments consistently, then processes have had to
  wait for space in the redo log buffer. The wait can be caused by the log
  buffer being too small or by checkpointing. Increase the size of the redo
  log buffer, if necessary, by changing the value of the initialization
  parameter LOG_BUFFER. The value of this parameter is expressed in bytes.
  Alternatively, improve the checkpointing or archiving process.

  Another data source is to check whether the log buffer space wait event is
  not a significant factor in the wait time for the instance; if not, the
  log buffer size is most likely adequate.

redo entries:
  Number of times a redo entry is copied into the redo log buffer.

redo log space requests:
  This reflects the number of times a user process waits for space in the
  redo log buffer. The LGWR writes redo entries from the redo log buffer to
  a redo log file.  Once LGWR copies the entries to the redo log file the
  user process can over write these entries.

redo log space wait time:
  Total elapsed waiting time for ´redo log space requests´.

redo size:
  Amount of redo generated.

redo synch writes:
  Number of times a change being applied to the log buffer must be written
  out to disk due to a commit. The log buffer is a circular buffer that
  LGWR periodically flushes. Usually, redo that is generated and copied into
  the log buffer need not be flushed out to disk immediately.

redo write time:
  Total elapsed time of the write from the redo log buffer to the current
  redo log file.

redo writes:
  Total number of writes by LGWR to the redo log files.

summary status all members:
  select member, status from v$logfile;

  If the status for any one member is not blank (which is ok), then ´ERROR´
  is delivered, else ´OK´.

member status info:
  This is only delivered in case of an error. It shows a list of those redo
  log file members that have a bad state in the form:

  <member> = <status>

  <member>
    The path and filename of the redo log member.

  <status>:
    INVALID: File is inaccessible
    STALE  : File´s contents are incomplete
    DELETED: File is no longer used

redo log switches:
  The number of redo log switches that have occurred since the last run.

inactive redo log files
  The number of inactive redo log files. If the number is zero, 
  or near zero for a longer time this can be an indicator of performance 
  problems indicated in AWR reports by 'waiting for free redo log'.
  Add more online redo logs or change to a bigger size for each of them.


#########################
*System Statistics
=================

See also the description by Oracle, e.g. for Oracle 12.1 at https://docs.oracle.com/database/121/REFRN/GUID-2FBC1B7E-9123-41DD-8178-96176260A639.htm


consistent changes:
  The number of times a database block has applied rollback entries
  to perform a consistent read on the block.

db block changes:
 This counts the total number of changes that were made to all blocks
 in the SGA that were part of an update or delete operation.

DBWR checkpoint buffers written:
   The number of buffers that were written for checkpoints.

execute count:
  Sum of all sql calls, including recursives. In an OLTP system the execute 
  count should be remarkable higher than the parse count.

parse count (total):
  Total number of parse calls (hard, soft, and describe). A soft parse
  is a check on an object already in the shared pool, to verify that
  the permissions on the underlying object have not changed.

parse count (hard):
  Total number of parse calls (real parses). A hard parse is a very expensive operation
  in terms of memory use, because it requires Oracle to allocate a workheap
  and other memory structures and then build a parse tree.
  (If this metric has high values, check if application uses bind variables).

physical reads:
  Number of blocks that had to be read from disk.

physical writes:
  Number of blocks that had to be written to disk.

recursive calls:
  Number of recursive calls generated at both the user and system level.
  Oracle maintains tables used for internal processing. When Oracle needs to make
  a change to these tables, it internally generates an internal SQL statement,
  which in turn generates a recursive call.

  A high figure of recursive calls (compared to total calls) may indicate any of the following:

    * Dynamic extension of tables due to poor sizing
    * Growing and shrinking of rollback segments due to unsuitable OPTIMAL settings
    * Large amounts of sort to disk resulting in creation and deletion of temporary segments
    * Data dictionary misses
    * Complex triggers, integrity constraints, procedures, functions and/or packages

table fetch continued row:
  When a row spans more than one block during a fetch then this figure is incremented.

  Retrieving rows that span more than one block increases the logical I/O by a factor
  that corresponds to the number of blocks than need to be accessed. Exporting and
  re-importing may eliminate this problem. Evaluate the settings for the storage
  parameters PCTFREE and PCTUSED. This problem cannot be fixed if rows are larger than
  database blocks (for example, if the LONG data type is used and the rows are extremely large).

table scan rows gotten:
  The number of rows processed during scan operations.

table scans (short tables):
table scans (long tables):
  Short tables may be scanned by Oracle when this is quicker than using an
  index. Full table scans of long tables is generally bad for overall
  performance. High figures for this may indicate lack of indexes on large
  tables or poorly written SQL which fails to use existing indexes or
  is returning a large percentage of the table.

transaction rollbacks:
  Number of transactions being successfully rolled back.

  These transactions are automatically rolled back by Oracle,
  this happens for example in case of constraint violation (i.e. Primary Key violation).

sorts (disk):
  The number of sort operations that needed disk writes. Sorts that require
  I/O to disk are quite resource intensive. Try increasing the size of the
  initialization parameter SORT_AREA_SIZE.

sorts (memory):
  The number of sorts in memory (no disk writes). This is more an indication
  of sorting activity in the application work load. You cannot do much better
  than memory sorts, except maybe no sorts at all. Sorting is usually caused
  by selection criteria specifications within table join SQL operations.

# workarea executions - optimal:
# workarea executions - onepass:
# workarea executions - multipass:
#
user calls:
  This is incremented each time Oracle allocates resources for a user
  (log in, parse, execute).

user commits:
  The number of committed user transactions.

user rollbacks:
  Number of times users manually issue the ROLLBACK statement
  or an error occurs during a user's transaction.



###########################
*Latches
=======
Oracle collects statistics for the activity of all latches and stores
these in this view. Values are only gathered if gets or misses are
greater than 10 since the last script run.

gets:
  Is the number of successful willing to wait requests for a latch.

misses:
  Is how many times a process didn't successfully request a latch.

successful:
  Is the percentage how often a request missed a latch.

###########################
*Tablespace Usage
================

Information about the tablespaces.

potential max size:
  The maximum size that the tablespace can grow to, depending 
  on the settings of the data (or temp) files, whether 
  AUTOEXTEND is ON or OFF and to what value maxsize is set.
  There is no need to increase the data files until this value 
  has not been reached.

current size:
  Current size of the tablespace. It may grow up to potential max size.

used:
  Space used within the tablespace.
  For temporary tablespaces: the sum of the size of all currently
  existing user objects in the tablespace.

%used_pms:
  Percentage of usage in relation to the potential max size.

     100 * used
  ------------------
  potential max size

For temporary tablespaces only:

used (lazy), %used (lazy):
  These figures reflect the "normal" space usage of the temporary
  tablespace. But the space is only reused on demand (lazy) after
  all the free space has been used up.

###########################
*Open Cursors
============
See:
  http://orafaq.com/node/758)

  and the Oracle Database Reference

Open cursors take up space in the shared pool, in the library cache. To keep a renegade session from filling up the library cache, or clogging the CPU with millions of parse requests, the parameter OPEN_CURSORS is set.

OPEN_CURSORS sets the maximum number of cursors each session can have open. For example, if OPEN_CURSORS is set to 1000, then each session can have up to 1000 cursors open at one time. If a single session has OPEN_CURSORS of cursors open, it will get an ORA-1000 error when it tries to open one more cursor.

Raise the OPEN_CURSORS parameter if sessions reach the current limit. If a session continuously gets an ORA-1000, it may indicate a leak in the application code.

open_cursors:
  The specified parameter.

count:
  Number of all opened cursors for all sessions.

max:
  The maximum number of opened cursors for one session.

avg:
  The average number of opened cursors for all sessions.

###########################
*Session Cached Cursors
======================
(see http://orafaq.com/node/758)

SESSION_CACHED_CURSORS sets the number of cached closed cursors each session can have. If SESSION_CACHED_CURSORS is not set, it defaults to 0 and no cursors will be cached for your session. (Your cursors will still be cached in the shared pool, but your session will have to find them there.) If it is set, then when a parse request is issued, Oracle checks the library cache to see whether more than 3 parse requests have been issued for that statement. If so, Oracle moves the session cursor associated with that statement into the session cursor cache. Subsequent parse requests for that statement by the same session are then filled from the session cursor cache, thus avoiding even a soft parse.

The obvious advantage to caching cursors by session is reduced parse times, which leads to faster overall execution times. This is especially so for applications like Oracle Forms applications, where switching from one form to another will close all the session cursors opened for the first form. Switching back then opens identical cursors. So caching cursors by session really cuts down on reparsing.

session_cached_cursors:
  The specified parameter.

sessions hit limit:
  Percentage of sessions having reached the number of session
  cached cursors as specified as parameter. (Some sessions may
  never reach the specified session_cached_cursors)

avg:
  Average number of session cached cursors for all sessions.

###########################
*alert.log
=========

The alert.log of the Oracle database instance is checked for occurrences of error pattern:
  ORA-
  Errors in file
  Corrupt block
  Process...died


error entry:
  Contains the matching lines of the alert.log
  Only present, if errors have been found.
  A maximum of 20 error entries will be reported in one script run.

first lines of trace file:
  If a trace file is referenced in the alert.log, like 
  "Errors in file .../xyz_ora_12345.trc", then the first lines 
  of that trace file are extracted. That should give a clue
  about the problem.

action:
  The alert.log has shrunk compared to the last script run, 
  it is searched from the beginning. 

###########################
*Jobs
====
You can schedule routines (jobs) to be run periodically using the job queue. To schedule a job you submit it to the job queue, using the Oracle supplied DBMS_JOB package, and specify the frequency at which the job is to be run. Additional functionality enables you to alter, disable, or delete a job that you previously submitted.

Job queue (Jnnn) processes execute jobs in the job queue. For each instance, these job queue processes are dynamically spawned by a coordinator job queue (CJQ0) background process.

The JOB_QUEUE_PROCESSES initialization parameter controls whether a coordinator job queue process is started by an instance. If this parameter is set to 0, no coordinator job queue process is started at database startup, and consequently no job queue jobs are executed.

Jobs are deprecated since Oracle 10.2, use now DBMS_SCHEDULER.

If the execution interval of a job is smaller than the execution interval of this monitoring script, not all job executions may be reported and some figures may be wrong. Check 'last execution before' to be sure that all job executions are catched.

All jobs that have not been executed for more than 32 days are ignored.

broken:
  Oracle has failed to successfully execute the job after
  16 attempts. Or you have marked the job as broken, using
  the procedure DBMS_JOB.BROKEN. Once a job has been marked
  as broken, Oracle will not attempt to execute the job until
  it is either marked not broken, or forced to be execute by
  calling the DBMS_JOB.RUN.

failures:
  Number of times the job has started and failed since its last success.

last execution before:
  The time in hours that has elapsed since the last execution
  of the job.

runtime:
  The time that the job needed to execute at its last execution.

start-stop:
  The start and stop time tupel for the last execution of the job.

what:
  The executed command.

###########################
*Scheduler
=========

Oracle Scheduler is a feature of Oracle database. It enables users to schedule jobs running inside the database such as PL/SQL procedures or PL/SQL blocks as well as jobs running outside the database such as shell scripts.

scheduler log:
  Lists the log entries of the scheduled jobs.

###########################
*Schema Information
==================

Some metrics gathered about all schemata that are not created at database installation. So normally, the system schemata should not appear.

allocated space:
  The allocated space (tables, indexes, ...) of the schema as found in dba_segments.


###########################
*Flashback
=========

(this documentation section needs revision)

"Flashback database" is a new feature in Oracle 10g that allows a DBA to revert an entire database back to an earlier point in time. Depending upon the length of time of the required flashback, it is often significantly faster and easier to flashback the database than perform a point-in-time recovery.

flashback feature enabled:
  YES if the flashback area is enabled.

recovery_file_dest:
  Path of the flashback area.

size:
  Size of the flashback area.

used:
  Used space in the flashback area.

%used:
  Percentage of used space in the flashback area.

oldest flashback timestamp:
  The earliest time the database can be flashed back to.
 
retention target:
  Planned number of minutes to keep the flashback data.


###########################
*Components
==========

This displays information about all components in the database that are loaded into the component registry of the Oracle Database.

components:
  A report of component, version, status and last modified of 
  each component selected from table dba_registry.


###########################
*Fast Recovery Area
==================
Starting in Oracle 11g release 2, Oracle has re-named the flash recovery area to be the fast recovery area.

The Fast Recovery Area is a unified storage location for all Oracle Database files related to recovery. When you set the parameters DB_RECOVERY_FILE_DEST and DB_RECOVERY_FILE_DEST_SIZE, RMAN backups, archive logs, control file automatic backups, and database copies can be written to the Fast Recovery Area. RMAN automatically manages files in the Fast Recovery Area by deleting obsolete backups and archive files no longer required for recovery.

recovery_file_dest:
  Location name. This is the value specified in the 
  DB_RECOVERY_FILE_DEST initialization parameter.

size:
  Maximum amount of disk space (in MB) that the database can use for 
  the fast recovery area. This is the value specified in the 
  DB_RECOVERY_FILE_DEST_SIZE initialization parameter.

used:
  Amount of disk space (in MB) used within the fast recovery area.

%used:
  Percentage of used disk space in the fast recovery area.

reclaimable:
  Total amount of disk space (in MB) that can be freed by deleting 
  obsolete, redundant, and other low priority files from the 
  flash recovery area.

number of files:
  Number of files in the flash recovery area.

##########################
*Audit Information
=================

This gathers the failed logins since last run of this script and reports that count to the ULS-server.
Table dba_audit_session is queried.

successful logins:
  Count of successful logins since last script run.

failed logins:
  Count of failed logins since last script run.

failed login report:
  A text file failed_login_report.txt that contains a report 
  that lists all users (OS USERNAME), their computer names (USER HOST) and 
  the timestamps (TIMESTAMP) at which they tried to connect to the database 
  with which database user (DB USERNAME).

  Example:

  TIMESTAMP           | OS USERNAME | USER HOST    | DB USERNAME
  ------------------- | ----------- | ------------ | -----------
  2013-12-24 23:59:59 | os_username | computername | db_schema

  IMPORTANT: 
    This usually contains real user names and real computernames, 
    That might not be in compliance with your privacy commitment!
    You may disable this report in the configuration file.
    Search for: OPTIONS

##########################
*Administrative Database User
============================
This is the list of users with DBA privileges and who are not Oracle maintained.
For security reasons, there should be NONE of them.

The list is retrieved with the SQL command:

select GRANTEE, GRANTED_ROLE, ADMIN_OPTION, DELEGATE_OPTION, DEFAULT_ROLE 
  from (
    select * from dba_role_privs where GRANTED_ROLE = 'DBA' and COMMON != 'YES'
    union
    select * from sys.dba_role_privs where ADMIN_OPTION = 'YES' and COMMON != 'YES'
  )
where GRANTEE != 'DBA' and GRANTEE != 'SYS';

###########################
*auto optimizer stats collection
===============================

This is the full list of all executions of the job 'auto optimizer stats collection' and its final job status (mostly: SUCCEEDED or STOPPED). STOPPED means, that the duration of the maintenance window was not sufficient for the complete statistics collection.

maintenance window:
  The mainenance window when the job was started.

window start time:
  The start time of the maintenance window.

window stop time:
  The stop time of the maintenance window.

job status:
  The status of the job.

job duration:
  The duration (run time) of the job in seconds.

job error:
  Shows the error number of the job, only if the job did not succeed.

job info:
  Only present if the job status is not SUCCEEDED. 
  It shows the reason for the unsuccessful termination of the job.
 
###########################
*blocking sessions
=================

Blocking sessions occur when one sessions holds an exclusive lock 
on an object and doesn't release it before another sessions wants 
to update the same data. 
This will block the second (or more) session until the first one has done its work.

From the view of the user it will look like the application 
completely hangs while waiting for the first session to release its lock. 
You'll often have to identify these sessions in order to improve 
your application to avoid as many blocking sessions as possible.

If necessary, you must kill the appropriate session by using command:

  ALTER SYSTEM KILL SESSION 'sid,serial#' immediate;

Replace 'sid' and 'serial#' by the values that you find in 'blocking session'.

And you must probably check repetitively for further blocking sessions by using the command:

  SELECT username, osuser, machine, sid, serial#  from v$session
  where sid in (select distinct FINAL_BLOCKING_SESSION from v$session
                where final_blocking_session_status = 'VALID');

and kill those session likewise.


count:
  The number of blocked sessions.

blocking session:
  This is the session that causes the blocking of all 'count' sessions and which must be killed.
  osusername @ machine / dbusername / SID,SERIAL#:sid,serial#


#############################
*pdb service test
================

This tests the availability of the listener service of a pdb.
The 'lsnrctl status listener_$ORACLE_SID' is used to retrieve the
ip address and the port of the listener, then a 'tnsping <ip>:<port>/<pdb_name>' is used to
check the availability of the pdb service.

If successful, nothing will be sent to ULS, only if an error or not connection to the
pdb listener service is possible, an error will be reported.

output:
  The command and the output of the command that failed.


#########################
*consumed resources
==================

This averages the entries of the last 10 minutes of  V$RSRCMGRMETRIC_HISTORY which contains information about CPU utilization, memory usage and wait times even when no Resource Manager plan is set. All metrics belong to the specific pdb.

avg iops:
  I/O operations per second.

avg iombps:
  I/O megabytes per second

cpu consumed time:
  Consumed cpu time.

SGA usage:
  SGA memory usage.

buffer cache usage:
  Buffer cache memory usage.

shared pool usage:
  Shared pool memory usage.

PGA usage:
  PGA memory usage.

