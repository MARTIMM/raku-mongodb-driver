use v6.d;

# also keep this the same as in t/Test-support.pm6
constant SERVER-VERSION1 = '4.0.5';
constant SERVER-VERSION2 = '4.0.18';

unit class Build;

#-------------------------------------------------------------------------------
has Str $!dist-path;
#-------------------------------------------------------------------------------
method build( Str $!dist-path ) {
  # do build stuff to your module which is located at $!dist-path

  self.download(SERVER-VERSION1);
  self.download(SERVER-VERSION2);
}

#-------------------------------------------------------------------------------
method download ( Str $sversion ) {

  # test if version directory exists. saves us a download
  if "$!dist-path/t/Travis-ci/$sversion".IO.d {
    note "MongoDB server version $sversion already downloaded";
  }
  else {
    note "Download server version $sversion";
    shell "$!dist-path/t/Travis-ci/install-mongodb.sh $sversion";
  }
}
