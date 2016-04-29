use v6.c;
use MongoDB::Log :ALL;

sub EXPORT { {
    '&set-exception-process-level'      => &set-exception-process-level,
    '&set-exception-processing'         => &set-exception-processing,
    '&set-logfile'                      => &set-logfile,
    '&open-logfile'                     => &open-logfile,

    '&trace-message'                    => &trace-message,
    '&debug-message'                    => &debug-message,
    '&info-message'                     => &info-message,
    '&warn-message'                     => &warn-message,
    '&error-message'                    => &error-message,
    '&fatal-message'                    => &fatal-message,
  }
};

package MongoDB:ver<0.28.12> {

  # Status values used by Server, Client and Monitor
  subset ServerStatus of Int where 10 <= $_ <= 22;

  constant C-UNKNOWN-SERVER             = 10;
  constant C-NON-EXISTENT-SERVER        = 11;
  constant C-DOWN-SERVER                = 12;
  constant C-RECOVERING-SERVER          = 13;

  constant C-REJECTED-SERVER            = 14;
  constant C-GHOST-SERVER               = 15;

  constant C-REPLICA-PRE-INIT           = 16;
  constant C-REPLICASET-PRIMARY         = 17;
  constant C-REPLICASET-SECONDARY       = 18;
  constant C-REPLICASET-ARBITER         = 19;

  constant C-SHARDING-SERVER            = 20;
  constant C-MASTER-SERVER              = 21;
  constant C-SLAVE-SERVER               = 22;

  #-------------------------------------------------------------------------------
  #
  signal(Signal::SIGTERM).tap: {say "Hi"; die "Stopped by user"};

}
