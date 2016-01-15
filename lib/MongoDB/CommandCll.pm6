use v6;
use MongoDB::Collection;

package MongoDB {

  class CommandCll is MongoDB::Collection {

    #---------------------------------------------------------------------------
    method BUILD ( :$database!, Str :$name ) {

      self._set_name('$cmd');
    }
  }
}
