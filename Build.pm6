use v6.d;

# also keep this the same as in t/Test-support.pm6
constant SERVER-VERSION1 = '4.0.5';
constant SERVER-VERSION2 = '4.0.18';

unit class Build;

method build( $dist-path ) {
  # do build stuff to your module
  # which is located at $dist-path

  shell "$dist-path/t/Travis-ci/install-mongodb.sh " ~ SERVER-VERSION1;
  shell "$dist-path/t/Travis-ci/install-mongodb.sh " ~ SERVER-VERSION2;
}
