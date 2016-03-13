use v6.c;
use MongoDB::Log :ALL;

  sub EXPORT { {
      '&set-exception-process-level'    => &set-exception-process-level,
      '&set-exception-processing'       => &set-exception-processing,
      '&set-logfile'                    => &set-logfile,
      '&open-logfile'                   => &open-logfile,

      '&trace-message'                  => &trace-message,
      '&debug-message'                  => &debug-message,
      '&info-message'                   => &info-message,
      '&warn-message'                   => &warn-message,
      '&error-message'                  => &error-message,
      '&fatal-message'                  => &fatal-message,
    }
  };

#-------------------------------------------------------------------------------
#
package MongoDB:ver<0.28.7> { }

