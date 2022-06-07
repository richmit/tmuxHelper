#!/bin/bash
# -*- Mode:Shell-script; Coding:us-ascii-unix; fill-column:158 -*-
################################################################################################################################################################
##
# @file      stmux.sh
# @author    Mitch Richling <https://www.mitchr.me>
# @brief     Start tmux server (new, default, or menu to select a server).@EOL
# @keywords  tmux
# @std       bash
# @copyright
#  @parblock
#  Copyright (c) 2016, Mitchell Jay Richling <https://www.mitchr.me> All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
#  1. Redistributions of source code must retain the above copyright notice, this list of conditions, and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions, and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#
#  3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without
#     specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
#  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
#  TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  @endparblock
# @filedetails
#
#  I love tmux, and I have some very specific, some say bazaar, preferences regarding how to make the best use of it.  This little script helps to integrate
#  tmux into my personal work flow as efficiently as possible.  Here are some things I care about:
#  
#    * I frequently create multiple tmux servers on a single system with each server hosting a number of logically related sessions.
#      * The sessions are named ##_hostname where ## is a zero padded, two digit integer
#      * The first one started is numbered "00" and is the one I connect to most frequently
#    * tmux sessions started outside of tmux should always have a default target working directory of the $PWD from which they were started
#    * tmux session names are *almost* always related to the $PWD
#       +------------------------+--------------+
#       | PWD                    | Session Name |
#       |------------------------+--------------|
#       | /home/richmit          | richmit      |
#       | /foo/2030-02-03_foobar | foobar       |
#       +------------------------+--------------+
#    * When connecting to a tmux server, I *almost* always
#      * Connect to an existing session started in the current $PWD
#      * Start a new session in the current $PWD
#    * When not doing the *almost* always thing
#      * Easy overrides on the command line
#      * Visual selection of servers/sessions via a terminal menu
#    * The *almost* always things
#      * Must be easy and quick
#      * Require the least typing
#
################################################################################################################################################################

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Set some defaults n stuff
SERVER_SOCK_PATH=~/tmp/tmux/sockets
DATE=`date +%s`
HOSTNAME=`hostname | cut -f1 -d.`
DEFAULT_SESSION_NAME=`basename "$PWD"`

DEFAULT_SERVER_SOCKN=''
for f in ${SERVER_SOCK_PATH}/[0-9]_${HOSTNAME}; do
  if [ -e ${f} ] ; then
    if tmux -S "${f}" has-session 2>/dev/null; then
      DEFAULT_SERVER_SOCKN=`basename ${f}`
      break
    else
      rm -f ${f}
      echo "stmux.sh: WARNING: Removed socket file with no running server: $f"
    fi
  fi
done

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Process arguments and populate REQ_SERVER, REQ_SERVER_FORM, REQ_SESSION, REQ_SESSION_FORM
if [ -z "$1" ] ; then                   # No arguments
  REQ_SERVER='q'
  REQ_SESSION='d'
  REQ_SERVER_FORM='CHAR'
  REQ_SESSION_FORM='CHAR'
elif [[ -n "$2" ]] ; then               # Two arguments
  REQ_SERVER="$1"
  REQ_SESSION="$2"
  if [[ "$REQ_SERVER" =~ ^[ndq]$ ]] ; then
    REQ_SERVER_FORM='CHAR'
  elif [[ "$REQ_SERVER" =~ ^[0-9]$ ]] ; then
    REQ_SERVER_FORM='NUMBER'
  elif [[ "$REQ_SERVER" =~ ^[0-9][0-9]$ ]] ; then
    REQ_SERVER_FORM='NUMBER'
  else
    REQ_SERVER_FORM='FILENAME'
    # May add support for direclty providing the socket name
    echo "ERROR: server must be an integer or a single character (n, d, q)"
    exit
  fi
  if [[ "$REQ_SESSION" =~ ^[ndq]$ ]] ; then
    REQ_SESSION_FORM='CHAR'
  else
    REQ_SESSION_FORM='NAME'
  fi
elif [[ "$1" =~ ^[ndq]$ ]] ; then       # Just a session (new, default, query)
  REQ_SERVER='d'
  REQ_SESSION="$1"
  REQ_SERVER_FORM='CHAR'
  REQ_SESSION_FORM='CHAR'
elif [[ "$1" =~ ^[ndq][ndq]$ ]] ; then  # server & session (new, default, query)
  REQ_SERVER=${1:0:1}
  REQ_SESSION=${1:1:1}
  REQ_SERVER_FORM='CHAR'
  REQ_SESSION_FORM='CHAR'
elif [[ "$1" =~ ^-[hH] ]] ; then
  echo 'Fire up a tmux client (and potentially a tmux server).               '
  echo 'Use:                                                                 '
  echo '  FULL FORM:                                                         '
  echo '    stmux.sh [[server-name] session-name]                            '
  echo '      The server argument may take one of two forms:                 '
  echo '        - One of the single characters: n, d, q                      '
  echo '            n = new    d = default   q = query                       '
  echo '          When missing this argument defaults to "d"                 '
  echo '        - One or two decimal digits                                  '
  echo '          The two digit numeric suffix of a standard                 '
  echo '          stmux.sh socket name (i.e. "hostname_suffix").             '
  echo '          A single digit will be zero padded. If no server           '
  echo '          exists with this suffix, then one will be created.         '
  echo '      The session may take one of two forms                          '
  echo '        - One of the single characters: n, d, q                      '
  echo '            n = new    d = default   q = query                       '
  echo '          When missing this argument defaults to "d"                 '
  echo '        - The name of a session                                      '
  echo '  QUICK FORM:                                                        '
  echo ' stmux.sh [[server]session]                                          '
  echo '   - Note this is a single arument of one or two characters.         '
  echo '   - server & session are single characters: n, d, q                 '
  echo '   - See the FULL FORM & NOTES for what these characters mean.       '
  echo ' NOTES:                                                              '
  echo '  - Do not name a server or session "n", "d", or "q"!!               '
  echo '  - No argument is the same as: qd                                   '
  echo '  - If no server is running, then "default" & "query"                '
  echo '    for the servers option become "new"                              '
  echo '  - If a server is running, then the "default" server is one with    '
  echo '    the lowest suffix number.                                        '
  echo '  - "default" session means "new" when a server is being started     '
  echo '  - If a session name is not explicitly provided, then new           '
  echo '    sessions will have a name set to the basename of the $PWD        '
  echo '    unless the desired server already has a session with this name.  '
  echo '    in which case a session with a numeric name will be created.     '
  echo '  - When connecting to an existing server, the "default" session     '
  echo '    is the session with a name of the basename of the $PWD if it     '
  echo '    exists.  Otherwise it will be the tmux defaults session.         '
  echo '  - New sessions have the $PWD as the default directory              '
  exit
else # Must be a session name
  REQ_SERVER='d'
  REQ_SESSION="$1"
  REQ_SERVER_FORM='CHAR'
  REQ_SESSION_FORM='NAME'
fi

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Check argument combinations.  Fix what we can

if [ -n "$3" ] ; then
  if [ -n "$DEBUG_STMUX" ] ; then echo "stmux.sh: WARNING: Arguments beyond the first two are ignord!"; fi
fi

# If we don't have a running server, then "default" and "query" mean "new"...
if [ -z "$DEFAULT_SERVER_SOCKN" ] ; then
  if [ "$REQ_SERVER"  = 'd' -o "$REQ_SERVER"  = 'q' ] ; then
    REQ_SERVER='n';
    if [ -n "$DEBUG_STMUX" ] ; then echo "stmux.sh: WARNING: Changeing server from 'd' to 'n' -- we don't have any running servers!"; fi
  fi
  if [ "$REQ_SESSION" = 'd' -o "$REQ_SESSION" = 'q' ] ; then
    REQ_SESSION='n';
    if [ -n "$DEBUG_STMUX" ] ; then echo "stmux.sh: WARNING: Changeing session from 'd' to 'n' -- we don't have any running servers!"; fi
  fi
fi

if [ "$REQ_SERVER" = 'n' -a "$REQ_SESSION" = 'q' ] ; then
  REQ_SESSION='n';
  if [ -n "$DEBUG_STMUX" ] ; then echo "stmux.sh: WARNING: Starting new server.  Changeing session from 'q' to 'n'!"; fi
fi

if [ "$REQ_SERVER" = 'n' -a "$REQ_SESSION" = 'd' ] ; then
  REQ_SESSION='n';
  if [ -n "$DEBUG_STMUX" ] ; then echo "stmux.sh: WARNING: Starting new server.  Changeing session from 'd' to 'n'!"; fi
fi
if [ ! -d "$SERVER_SOCK_PATH" ] ; then
  echo "ERROR: server socket path is missing: $SERVER_SOCK_PATH"
  exit
fi

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Figure out which GUI tool to use
if [ "$REQ_SERVER" = 'q' -o "$REQ_SESSION" = 'q' ] ; then
  DIALOG_CMD=''
  DIALOG_CMD_FLAVOR=''
  for f in '/home/richmit/s/linux/local/bin/dialog' '/usr/bin/dialog' ~/bin/dialog '/usr/bin/whiptail' ; do
    if [ -e "$f" ] ; then
      DIALOG_CMD="$f"
      DIALOG_CMD_FLAVOR=`basename $f | tr 'a-z' 'A-Z'`
      break
    fi
  done
  if [ -z "$DIALOG_CMD" ] ; then
    echo "stmux.sh: ERROR: Could not find dialog or whiptail -- 'q' option is not supported!"
    exit
  fi
fi

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Populate SERVER_SOC varaibles
case "$REQ_SERVER_FORM" in
  'NUMBER'   ) SERVER_SOCK=`printf '%s/%d_%s' $SERVER_SOCK_PATH $REQ_SERVER $HOSTNAME`;
               if tmux -S "${SERVER_SOCK}" has-session 2>/dev/null; then
                 CREATE_NEW_SERVER='N'
               else
                 CREATE_NEW_SERVER='Y'
               fi
               ;;
  'CHAR'     ) case "$REQ_SERVER" in
                 'q' ) if [ "$DIALOG_CMD_FLAVOR" = 'DIALOG' ] ; then
                         SOCKS='NEW'
                       else
                         SOCKS='NEW NEW'
                       fi
                       for f in ${SERVER_SOCK_PATH}/[0-9]_${HOSTNAME}; do
                         if [ -e ${f} ] ; then
                           if tmux -S "${f}" has-session 2>/dev/null; then
                             s=`basename ${f}`
                             if [ "$DIALOG_CMD_FLAVOR" = 'DIALOG' ] ; then
                               SOCKS="$SOCKS $s"
                             else
                               SOCKS="$SOCKS $s $s"
                             fi
                           else
                             rm -f ${f}
                             echo "stmux.sh: WARNING: Removed socket file with no running server: $f"
                           fi
                         fi
                       done
                       TMPFILE=/tmp/tmux.$HOSTNAME.$BASH_PID.$DATE.$RANDOM
                       if [ -n "$SOCKS" ] ; then
                         $DIALOG_CMD --noitem --menu 'Select a tmux server' 20 50 15 $SOCKS 2> $TMPFILE
                       fi
                       SERVER_SOCK=`cat $TMPFILE`
                       rm $TMPFILE
                       clear
                       if [ -z "$SERVER_SOCK" ] ; then
                         if [ -n "$DEBUG_STMUX" ] ; then echo "stmux.sh: WARNING: Canceled interactive server selection!"; fi
                         exit
                       fi
                       if [ "$SERVER_SOCK" = 'NEW' ] ; then
                         SERVER_SOCK='n'
                         CREATE_NEW_SERVER='Y'
                       else
                         CREATE_NEW_SERVER='N'
                         if [ ! -e "$SERVER_SOCK" -a -e "$SERVER_SOCK_PATH/$SERVER_SOCK" ] ; then
                           SERVER_SOCK="$SERVER_SOCK_PATH/$SERVER_SOCK"
                         fi
                       fi
                       ;;
                 'd' ) SERVER_SOCK="${SERVER_SOCK_PATH}/${DEFAULT_SERVER_SOCKN}";
                       CREATE_NEW_SERVER='N'
                       ;;
                 'n' ) SERVER_SOCK='n'
                       CREATE_NEW_SERVER='Y'
                       ;;
               esac ;;
esac

if [ "$CREATE_NEW_SERVER" = 'Y' -a "$SERVER_SOCK" = 'n' ]; then
  for i in `seq 0 99`; do
    SERVER_SOCK=`printf '%s/%d_%s' $SERVER_SOCK_PATH $i $HOSTNAME`
    if [ ! -e "$SERVER_SOCK" ] ; then
      break
    fi
    if ! tmux -S "${SERVER_SOCK}" has-session 2>/dev/null; then
      if [ -n "$DEBUG_STMUX" ] ; then echo "stmux.sh: INFO: Found socket file with no tmux process: $SERVER_SOCK"; fi
      break
    else
      if [ -n "$DEBUG_STMUX" ] ; then echo "stmux.sh: INFO: Found socket file with a tmux process: $SERVER_SOCK"; fi
    fi
  done
fi

if [ -z "$SERVER_SOCK" ] ; then
  echo "stmux.sh: ERROR: Could not figure out server socket!"
  exit
fi

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Populate SESSION_NAME varaible
case "$REQ_SESSION_FORM" in
  'NAME' ) SESSION_NAME="$REQ_SESSION";
           if [ "$CREATE_NEW_SERVER" = 'N' ] ; then
             if tmux -S "$SERVER_SOCK" has-session -t "$SESSION_NAME" >/dev/null 2>/dev/null; then
               CREATE_NEW_SESSION='N'
             else
               CREATE_NEW_SESSION='Y'
             fi
           else
             CREATE_NEW_SESSION='Y'
           fi
           ;;
  'CHAR' ) case "$REQ_SESSION" in
             'q' ) if [ "$CREATE_NEW_SERVER" = 'Y' ]; then
                     SESSION_NAME='';
                     CREATE_NEW_SESSION='Y'
                   else
                     if [ "$DIALOG_CMD_FLAVOR" = 'DIALOG' ] ; then
                       SLIST='NEW '`tmux -S "$SERVER_SOCK" list-sessions -F '#S' | tr '\n' ' '`
                     else
                       SLIST='NEW NEW '`tmux -S "$SERVER_SOCK" list-sessions -F '#S #S' | tr '\n' ' '`
                     fi
                     TMPFILE=/tmp/tmux.$HOSTNAME.$BASH_PID.$DATE.$RANDOM
                     $DIALOG_CMD --noitem --menu 'Select a tmux server' 20 70 15 $SLIST 2> $TMPFILE
                     SESSION_NAME=`cat $TMPFILE`
                     rm $TMPFILE
                     clear
                     if [ -z "$SESSION_NAME" ] ; then
                       if [ -n "$DEBUG_STMUX" ] ; then echo "stmux.sh: WARNING: Canceled interactive session selection!"; fi
                       exit
                     fi
                     if [ "$SESSION_NAME" = 'NEW' ] ; then
                       SESSION_NAME='n'
                       CREATE_NEW_SESSION='Y'
                       SESSION_NAME=''
                     else
                       CREATE_NEW_SESSION='N'
                     fi
                   fi
                   ;;
             'd' ) SESSION_NAME='';
                   CREATE_NEW_SESSION='N'
                   ;;
             'n' ) SESSION_NAME='';
                   CREATE_NEW_SESSION='Y'
                   ;;
           esac ;
esac

if [ -n "$DEFAULT_SESSION_NAME" -a -z "$SESSION_NAME" ] ; then
  if [ "$CREATE_NEW_SESSION" = "Y" ] ; then
    if [ "$CREATE_NEW_SERVER" = "Y" ] ; then
      SESSION_NAME="$DEFAULT_SESSION_NAME"
    else
      if tmux -S "$SERVER_SOCK" has-session -t "$DEFAULT_SESSION_NAME" >/dev/null 2>/dev/null; then
        if [ -n "$DEBUG_STMUX" ] ; then echo "stmux.sh: WARNING: Session with automatic PWD-based name already exists.  Creating anonymous session instead.!"; fi
      else
        SESSION_NAME="$DEFAULT_SESSION_NAME"
      fi
    fi
  else
    if tmux -S "$SERVER_SOCK" has-session -t "$DEFAULT_SESSION_NAME" >/dev/null 2>/dev/null; then
      SESSION_NAME="$DEFAULT_SESSION_NAME"
    fi
  fi
fi

# Fix various bad names for a session
if [ -n "$SESSION_NAME" ] ; then
  BACKUP_SESSION_NAME="$SESSION_NAME"
  SESSION_NAME=`echo -n "$SESSION_NAME" | sed 's/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_\(..*\)$/\1/'` # Change YYYY-MM-DD_foo => foo
  SESSION_NAME=`echo -n "$SESSION_NAME" | tr -c -s "[:alnum:]" '_'`                                         # Zap non-alphanumeric
  if [ "$DEBUG_STMUX" ] ; then
    if [ "$BACKUP_SESSION_NAME" != "$SESSION_NAME" ]; then
      echo "stmux.sh: WARNING: Session name string fixed.  FROM: '$BACKUP_SESSION_NAME' TO: '$SESSION_NAME'!";
    fi
  fi
fi


#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Print out info
if [ -n "$DEBUG_STMUX" ] ; then
  echo "SERVER_SOCK_PATH     : '${SERVER_SOCK_PATH}'   "
  echo "HOSTNAME             : '${HOSTNAME}'           "
  echo "DEFAULT_SERVER_SOCKN : '${DEFAULT_SERVER_SOCKN}'"
  echo "SERVER_SOCK          : '${SERVER_SOCK}'        "
  echo "REQ_SERVER           : '${REQ_SERVER}'         "
  echo "REQ_SERVER_FORM      : '${REQ_SERVER_FORM}'    "
  echo "REQ_SESSION          : '${REQ_SESSION}'        "
  echo "REQ_SESSION_FORM     : '${REQ_SESSION_FORM}'   "
  echo "SESSION_NAME         : '${SESSION_NAME}'       "
  echo "CREATE_NEW_SERVER    : '${CREATE_NEW_SERVER}'  "
  echo "CREATE_NEW_SESSION   : '${CREATE_NEW_SESSION}' "
fi

#---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Fire up tmux (or print out what we would do if DEBUG_STMUX is set)
if [ -n "$DEBUG_STMUX" ] ; then
  PRECMD='echo NOT RUNNING: '
else
  PRECMD=env
fi

ZSH_PATH=$(which zsh)
if [ -n "$ZSH_PATH" -a -x "$ZSH_PATH" ]; then
  export SHELL="$ZSH_PATH"
fi

if [ "$CREATE_NEW_SERVER" = "N" -a "$CREATE_NEW_SESSION" = "N" ] ; then
  if [ -z "$SESSION_NAME" ] ; then
    $PRECMD tmux -S "$SERVER_SOCK" attach
  else
    $PRECMD tmux -S "$SERVER_SOCK" attach      -t "$SESSION_NAME"
  fi
else
  SESSION_PWD=`pwd`
  if [ -n "$DEBUG_STMUX" ] ; then
    echo "SESSION_PWD          : '${SESSION_PWD}'        "
  fi
  if [ -z "$SESSION_NAME" ] ; then
    $PRECMD tmux -S "$SERVER_SOCK" new-session                    -c "$SESSION_PWD" 
  else
    $PRECMD tmux -S "$SERVER_SOCK" new-session -s "$SESSION_NAME" -c "$SESSION_PWD" 
  fi
fi
