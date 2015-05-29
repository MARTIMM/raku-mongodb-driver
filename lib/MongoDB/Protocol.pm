use v6;
use MongoDB::Wire;

package MongoDB {
  role MongoDB::Protocol {

    state MongoDB::Wire $wp = MongoDB::Wire.new;

    method wire ( --> MongoDB::Wire ) { return $wp };
  }
}
