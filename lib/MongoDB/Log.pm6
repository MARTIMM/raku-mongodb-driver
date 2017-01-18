use v6.c;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<https://github.com/MARTIMM>;

use Log::Async;
use Terminal::ANSIColor;

#-------------------------------------------------------------------------------
class Log is Log::Async {

  has Hash $!send-to-setup;

  #-----------------------------------------------------------------------------
  submethod BUILD ( ) {

    $!send-to-setup = {};
  }

  #-----------------------------------------------------------------------------
  # add channel
  method add-send-to (
    Str:D $key, :$level = INFO, Code :$code,
    Any :$to is copy = $*OUT, Str :$pipe
  ) {

    if $pipe {
      my Proc $p = shell( $pipe, :in) or die "error opening pipe to $pipe";
      $to = $p.in;
    }

    $!send-to-setup{$key} = [ $to, $level, $code];
    self!start-send-to;
  }

  #-----------------------------------------------------------------------------
  # drop channel
  method drop-send-to ( Str:D $key, Any :$to = $*OUT, :$level = INFO) {

    $!send-to-setup{$key}:exists and $!send-to-setup{$key}:delete;
    self!start-send-to;
  }

  #-----------------------------------------------------------------------------
  # start channels
  method !start-send-to ( ) {

    self.close-taps;
    for $!send-to-setup.keys -> $k {
      if ? $!send-to-setup{$k}[2] {
        logger.send-to:
          $!send-to-setup{$k}[0],
          :code($!send-to-setup{$k}[2]),
          :level($!send-to-setup{$k}[1])
        ;
      }
      
      else {
        logger.send-to: $!send-to-setup{$k}[0], :level($!send-to-setup{$k}[1]);
      }
    }
  }

  #-----------------------------------------------------------------------------
  # send-to method
  multi method send-to ( IO::Handle:D $fh, Code:D :$code!, |args ) {

    self.add-tap: -> $m { $m<fh> = $fh; $code($m); }, |args;
  }

  #-----------------------------------------------------------------------------
  # overload log method
  method log (
    Str:D :$msg, Loglevels:D :$level,
    DateTime :$when = DateTime.now.utc,
    Code :$code
  ) {

    my Hash $m;
    if ? $code {
      $m = $code( :$msg, :$level, :$when);
    }
    
    else {
      $m = { :$msg, :$level, :$when };
    }

    (start $.source.emit($m)).then({ say $^p.cause unless $^p.status == Kept });
  }
}

set-logger(MongoDB::Log.new);
logger.close-taps;

sub EXPORT { {
    '&logger'                           => &logger,
  }
};

#-------------------------------------------------------------------------------
class Message is Exception {
  has Str $.message;            # Error text and error code are data mostly
  has Str $.method;             # Method or routine name
  has Int $.line;               # Line number where Message is called
  has Str $.file;               # File in which that happened
}

#-------------------------------------------------------------------------------
# preparations of code to be provided to log()
sub search-callframe ( $type --> CallFrame ) {

  # Skip callframes for
  # 0  search-callframe(method)
  # 1  log(method)
  # 2  send-to(method)
  # 3  -> m { ... }
  # 4  *-message(sub) helper functions
  #
  my $fn = 5;
  while my CallFrame $cf = callframe($fn++) {
    # End loop with the program that starts on line 1 and code object is
    # a hollow shell.
    if ?$cf and $cf.line == 1  and $cf.code ~~ Mu {

      $cf = Nil;
      last;
    }

    # Cannot pass sub THREAD-ENTRY either
    if ?$cf and $cf.code.^can('name') and $cf.code.name eq 'THREAD-ENTRY' {

      $cf = Nil;
      last;
    }

    # Try to find a better place instead of dispatch, BUILDALL etc:...
    next if $cf.code ~~ $type and $cf.code.name ~~ m/dispatch/;
    last if $cf.code ~~ $type;
  }

  return $cf;
}

# log code with stack frames
my Code $log-code-cf = sub (
  Str:D :$msg, Loglevels:D :$level,
  DateTime :$when = DateTime.now.utc
  --> Hash
) {
  my CallFrame $cf;
  my Str $method = '';        # Method or routine name
  my Int $line = 0;           # Line number where Message is called
  my Str $file = '';          # File in which that happened

  $cf = search-callframe(Method);
  $cf = search-callframe(Submethod)     unless $cf.defined;
  $cf = search-callframe(Sub)           unless $cf.defined;
  $cf = search-callframe(Block)         unless $cf.defined;

  if $cf.defined {
    $line = $cf.line.Int // 1;
    $file = $cf.file // '';
    $file ~~ s/$*CWD/\./;
    $method = $cf.code.name // '';
  }

  hash(
    :thid($*THREAD.id),
    :$line, :$file, :$method,
    :$msg, :$level, :$when,
  );
}

# log code without stack frames
my Code $log-code = sub (
  Str:D :$msg, Loglevels:D :$level,
  DateTime :$when = DateTime.now.utc
  --> Hash
) {
  my Str $method = '';        # Method or routine name
  my Int $line = 0;           # Line number where Message is called
  my Str $file = '';          # File in which that happened

  hash(
    :thid($*THREAD.id),
    :$line, :$file, :$method,
    :$msg, :$level, :$when,
  );
}

sub trace-message ( Str $msg ) is export {
  logger.log( :$msg, :level(TRACE), :code($log-code));
}

sub debug-message ( Str $msg ) is export {
  logger.log( :$msg, :level(DEBUG), :code($log-code));
}

sub info-message ( Str $msg ) is export {
  logger.log( :$msg, :level(INFO), :code($log-code));
}

sub warn-message ( Str $msg ) is export {
  logger.log( :$msg, :level(WARNING), :code($log-code-cf));
}

sub error-message ( Str $msg ) is export {
  logger.log( :$msg, :level(ERROR), :code($log-code-cf));
}

sub fatal-message ( Str $msg ) is export {
  logger.log( :$msg, :level(FATAL), :code($log-code-cf));
  sleep 0.5;
  die MongoDB::Message.new( :message($msg));
}

#-------------------------------------------------------------------------------
# preparations of code to be provided to send-to()
# Loglevels enum counts from 1 so 0 has placeholder PH
my Array $sv-lvls = [< PH0 T D I W E F>];
my Array $clr-lvls = [
  'PH1',
  '0,150,150',
  '0,150,255',
  '0,200,0',
  '200,200,0',
  'bold white on_255,0,0',
  'bold white on_255,0,255'
];

my Code $code = -> $m {
  my Str $dt-str = $m<when>.Str;
  $dt-str ~~ s:g/ <[T]> / /;
  $dt-str ~~ s:g/ <[Z]> //;

  my IO::Handle $fh = $m<fh>;
  if $fh ~~ any( $*OUT, $*ERR) {
    $fh.print: color($clr-lvls[$m<level>]);
  }

  $fh.print: ( [~]
    $dt-str,
    ' [' ~ $sv-lvls[$m<level>] ~ ']',
    ? $m<thid> ?? " $m<thid>.fmt('%2d')" !! '',
    ? $m<msg> ?? ": $m<msg>" !! '',
    ? $m<file> ?? ". At $m<file>" !! '',
    ? $m<line> ?? ':' ~ $m<line> !! '',
    ? $m<method> ?? " in $m<method>" ~ ($m<method> eq '<unit>' ?? '' !! '()')
                 !! '',
  );

  $fh.print: color('reset') if $fh ~~ any( $*OUT, $*ERR);
  $fh.print: "\n";
};


#-------------------------------------------------------------------------------
sub add-send-to ( |c ) is export { logger.add-send-to( |c, :$code); }
sub drop-send-to ( |c ) is export { logger.drop-send-to( |c, :$code); }

#-------------------------------------------------------------------------------
# Activate some channels. Display messages only on error and fatal to the screen
# and all messages of type info, warning, error and fatal to a file MongoDB.log
add-send-to( 'screen', :to($*OUT), :level(* >= ERROR));
add-send-to( 'mongodb', :pipe('sort >> MongoDB.log'), :level(* >= TRACE));







=finish
#-------------------------------------------------------------------------------
# Definition of all severity types
#
enum Severity <Trace Debug Info Warn Error Fatal>;

# Must keep the following variables here because it must be possible to set
# these before creating the exception.
#
our $severity-process-level = Info;

our $do-log = True;
our $do-check = True;

our $log-fh;
our $log-fn = 'MongoDB.log';

#-------------------------------------------------------------------------------
# Logging always for Errors and Fatal
#
sub set-exception-process-level (
  Severity:D $s where Trace <= $s <= Warn
) is export {
  $severity-process-level = $s;
}

#-------------------------------------------------------------------------------
#
sub set-exception-processing (
  Bool :$logging = True,
  Bool :$checking = True
) is export {
  $do-log = $logging;
  $do-check = $checking;
}

#-------------------------------------------------------------------------------
#
multi sub set-logfile ( Str:D $filename! ) is export {
  $log-fn = $filename;
}

#-------------------------------------------------------------------------------
#
multi sub set-logfile ( IO::Handle:D $file-handle! ) is export {
  $log-fh.close if ? $log-fh and $log-fh !eqv $*OUT and $log-fh !eqv $*ERR;
  $log-fh = $file-handle;
}

#-------------------------------------------------------------------------------
#
sub open-logfile (  ) is export {
  $log-fh.close if ? $log-fh and $log-fh !eqv $*OUT and $log-fh !eqv $*ERR;
  $log-fh = $log-fn.IO.open: :a;
}

#-------------------------------------------------------------------------------
# A role to be used to handle exceptions.
#
role Logging {

  #-----------------------------------------------------------------------------
  #
  method mlog ( ) {

#say "P: ", $?PACKAGE;
#say "R: ", $?ROLE;
#say "C: ", $?CLASS;

#note "Mlog: {self.severity} >= $severity-process-level: ",
#    self.severity >= $severity-process-level;

    return unless ($do-log and (self.severity >= $severity-process-level));
#note "log message: {self.message}";

    # Check if file is open.
    #
    open-logfile() unless ? $log-fh;

    # Define log text. If severity > Info insert empty line
    #
    my Str $dt-str = $.date-time.utc.Str;
    $dt-str ~~ s/\.\d+Z$//;
    $dt-str ~~ s/T/ /;
    my Str $etxt ~= [~] $*THREAD.id().fmt('%2d '), $dt-str,
                 " [{(uc self.severity).substr(0,1)}] ",
                 self."{lc(self.severity)}"(),
                 "\n";
    $log-fh.print($etxt);
  }

  #-----------------------------------------------------------------------------
  # Absolute methods. Must be defined by user of this role
  #
  method trace ( --> Str ) { ... }
  method debug ( --> Str ) { ... }
  method info ( --> Str ) { ... }
  method warn ( --> Str ) { ... }
  method error ( --> Str ) { ... }
  method fatal ( --> Str ) { ... }

  method message ( --> Str ) { ... }
}


#-------------------------------------------------------------------------------
#
class Message is Exception does MongoDB::Logging {
  has Str $.message;            # Error text and error code are data mostly
  has Str $.code;               # originated from the mongod server
  has Str $.oper-data;          # Operation data are items sent to the server
  has Str $.collection-ns;      # Collection name space == dbname.clname
  has Str $.method;             # Method or routine name
  has Int $.line;               # Line number where Message is called
  has Str $.file;               # File in which that happened

  has MongoDB::Severity $.severity;   # Severity level
  has DateTime $.date-time;           # Date and time of creation.

  has Semaphore $control-logging;

  #-----------------------------------------------------------------------------
  #
  submethod BUILD ( ) {
    $control-logging .= new(1);
  }

  #-----------------------------------------------------------------------------
  #
  method log (
    Str:D :$message,
    :$code where $_ ~~ any(Int|Str) = '',
    Str :$oper-data = '',
    Str :$collection-ns = '',
    MongoDB::Severity :$severity = MongoDB::Severity::Warn,
  ) {
#say 'l 0';
    return
      unless ($do-log and ($severity >= $severity-process-level));


#say "l 1: {callframe(3).line} {callframe(3).file}";
    $control-logging.acquire;
#say "l 2";
#say "Severity $severity, $message";
    my CallFrame $cf = self!search-callframe(Method);
    $cf = self!search-callframe(Submethod) unless $cf.defined;
    $cf = self!search-callframe(Sub) unless $cf.defined;
    $cf = self!search-callframe(Block) unless $cf.defined;

    if $cf.defined {
      $!line = $cf.line.Int // 1;
      $!file = $cf.file // '';
      $!file ~~ s/$*CWD/\./;
      $!method = $cf.code.name // '';
    }

    else {
      $!line = 0;
      $!file = $!method = '';
    }

    $!message           = $message;
    $!code              = ~$code;
    $!oper-data         = $oper-data;
    $!collection-ns     = $collection-ns;

    $!severity          = $severity;
    $!date-time         .= now;

    self.mlog;

    # Must release the lock here because after a catched message the software
    # can again call log(). We clone this object so that a waiting thread is not
    # messing up the data
    #
    my $copy = self.clone;
#say "l 3";
    $control-logging.release;

#      return unless (
#        $do-check
#        and ($copy.severity >= MongoDB::Severity::Fatal)
#      );
#say "l 4";
    return $do-check ?? $copy !! Any;
  }

  #-----------------------------------------------------------------------------
  #
  method !search-callframe ( $type --> CallFrame ) {
#`{{
    my CallFrame $cf;
    for 1..Inf -> $level {

      given callframe($level) {
        when CallFrame {
          last if .line == 1;
          next if .annotations<file> ~~ m/^ 'gen/' /;
          next unless .defined and .^can('code') and .code ~~ Routine;

say "CD: ", (.code.^can('name') ?? .code.name !! '-'), ', ', .code.WHAT,
    ', ', .code.package.^name, ', ', .code.^name;

          $cf = $_;
        }

        default {
          last;
        }
      }
    }

    $cf;
}}
#`{{}}
    # Skip callframes for
    # 0  search-callframe(method)
    # 1  log(method)
    # 2  *-message(sub) helper functions
    #    Can be bypassed by using $MongoDB::logger.log() directly.
    #
    my $fn = 3;
    while my CallFrame $cf = callframe($fn++) {

      # End loop with the program that starts on line 1 and code object is
      # a hollow shell.
      #
      if ?$cf and $cf.line == 1  and $cf.code ~~ Mu {
        $cf = Nil;
        last;
      }

      # Cannot pass sub THREAD-ENTRY either
      #
      if ?$cf and $cf.code.^can('name') and $cf.code.name eq 'THREAD-ENTRY' {
        $cf = Nil;
        last;
      }

#say "cf $fn: ", $cf.line, ', ', $cf.code.WHAT, ', ', $cf.code.^name,
#', ', ($cf.code.^can('name') ?? $cf.code.name !! '-');

      # Try to find a better place instead of dispatch, BUILDALL etc:...
      #
      next if $cf.code ~~ $type
          and $cf.code.name ~~ m/dispatch/;
#            and $cf.code.name ~~ m/dispatch|BUILDALL|bless/;

      last if $cf.code ~~ $type;
    }

    return $cf;
  }

  #-----------------------------------------------------------------------------
  #
  method dump-callframes ( ) {

    my $fn = 1;
    while my CallFrame $cf = callframe($fn++) {

      # End loop with the program that starts on line 1 and code object is
      # a hollow shell.
      #
      if ?$cf and $cf.line == 1  and $cf.code ~~ Mu {
        last;
      }

      # Cannot pass sub THREAD-ENTRY either
      #
      if ?$cf and $cf.code.^can('name') and $cf.code.name eq 'THREAD-ENTRY' {
        last;
      }

      say $fn.fmt('%02d'), ': ' , $cf.line, ', ', $cf.code.WHAT,
          ', ', $cf.code.^name,
          ', ', ($cf.code.^can('name') ?? $cf.code.name !! '-');
    }
  }

  #-----------------------------------------------------------------------------
  #
  method trace ( --> Str ) {
    $!message;
#      [~] " $!message ", "[{$!method // ''}:$!line]";
  }

  #-----------------------------------------------------------------------------
  #
  method debug ( --> Str ) {
    $!message
#      return [~] " $!message ", "[{$!method // ''}:$!line]"
#                 ? $!code ?? " \({$!code})" !! '',
#                 ? $!collection-ns ?? "c-ns=$!collection-ns" !! '',
#                 ? $!method ?? " From method $!method" !! '',
#                 " at $!file\:$!line"
               ;
  }

  #-----------------------------------------------------------------------------
  #
  method info ( --> Str ) {
    $!message
#      return [~] "$!message ", "[{$!method // ''}:$!line]"
#                 ? $!code ?? " \({$!code})" !! '',
#                 ? $!collection-ns ?? " Collection namespace $!collection-ns." !! '',
#                 ? $!method ?? " From method $!method" !! '',
#                 " at $!file\:$!line"
               ;
  }

  #-----------------------------------------------------------------------------
  #
  method warn ( --> Str ) {
    return self.message;
  }

  #-----------------------------------------------------------------------------
  #
  method error ( --> Str ) {
    return self.message;
  }

  #-----------------------------------------------------------------------------
  #
  method fatal ( --> Str ) {
    return self.message;
  }

  #-----------------------------------------------------------------------------
  #
  method message ( --> Str ) {
    return [~] "\n  $!message.",
               ? $!code ?? " \({$!code})" !! '',
               ? $!oper-data ?? "\n  Request data: $!oper-data" !! '',
               ? $!collection-ns
                 ?? "\n  Collection namespace $!collection-ns" !! '',
               ? $!method ?? "\n  From method $!method" !! '',
               " at $!file\:$!line"
               ;
  }
}



# Declare a message object to be used anywhere
#
state MongoDB::Message $logger .= new;

sub combine-args ( $c, $s) {
  my %args = $c.kv;
  if $c.elems and $c<message>:!exists {
    my Str $msg = $c[0] // '';
    %args<message> = $msg;
  }
  %args<severity> = $s;
  return %args;
}

sub trace-message ( |c ) is export {
  $logger.log(|combine-args( c, MongoDB::Severity::Trace));
}

sub debug-message ( |c ) is export {
  $logger.log(|combine-args( c, MongoDB::Severity::Debug));
}

sub info-message ( |c ) is export {
  $logger.log(|combine-args( c, MongoDB::Severity::Info));
}

sub warn-message ( |c ) is export {
  $logger.log(|combine-args( c, MongoDB::Severity::Warn));
}

sub error-message ( |c ) is export {
  $logger.log(|combine-args( c, MongoDB::Severity::Error));
}

sub fatal-message ( |c ) is export {
  my $mobj = $logger.log(|combine-args( c, MongoDB::Severity::Fatal));
  die $mobj if $mobj.defined;
}

#  class Log {
#
#
#  }

