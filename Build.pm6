use v6.d;

#-------------------------------------------------------------------------------
unit class Build;

# also keep these lines the same as in t/Test-support.pm6
#constant SERVER-VERSION1 = '3.6.9';
constant SERVER-VERSION1 = '4.0.5';
constant SERVER-VERSION2 = '4.0.18';
# later builds have specific os names in the archive name
#constant SERVER-VERSION2 = '4.2.6';

has Str $!dist-path;
has Bool $!on-travis;

#-------------------------------------------------------------------------------
# do build stuff to your module which is located at $!dist-path
method build( Str $!dist-path ) {

  # in the download script. normally set when on travis-ci.
  #%*ENV<TRAVIS_BUILD_DIR> = $!dist-path unless %*ENV<TRAVIS_BUILD_DIR>:exists;

  $!on-travis = %*ENV<TRAVIS_BUILD_DIR>:exists;

  # check if installing on Travis or for a user. in the last case only
  # one version needs to be installed to save download and install time.
  self.download(SERVER-VERSION1);
  self.download(SERVER-VERSION2) if $!on-travis;

  1;
}

#-------------------------------------------------------------------------------
method download ( Str $sversion ) {

  # test if version directory exists. saves us a download
  if "$!dist-path/t/Travis-ci/$sversion".IO.d {
    note "MongoDB server version $sversion already downloaded";
  }
  else {
    note "Download server version $sversion";

    my Str ( $v1, $v2, $v3 ) = $sversion.split('.');
    my Str $osname = '';

    if $v1.Int >= 4 {
      #$osname = ...; -> test and rename e.g. rhel70;
    }

#    run 'bash', "$!dist-path/t/Travis-ci/install-mongodb.bash", $sversion, $osname

    # replaced bash program
    note "Installing MongoDB version $sversion";
    note "Build directory: $!dist-path";

    # create directory when on Travis or on user installments
    my Str $load-dir = "$!dist-path/t/Travis-ci";
    mkdir( $load-dir, 0o777) unless $load-dir.IO.e;
    my Str $downloadname;

    # if directory (named as a mongodb version) does not exist, download mongodb
    if not "$load-dir/$sversion".IO.e {
      chdir($load-dir);

      if ?$osname {
        $downloadname = "mongodb-linux-x86_64-{$osname}-$sversion";
      }

      else {
        $downloadname = "mongodb-linux-x86_64-$sversion";
      }

      # download archive
      shell "curl -O 'https://fastdl.mongodb.org/linux/$downloadname.tgz'";

      # only get mongod and mongos server programs
      shell "tar xvfz $downloadname.tgz $downloadname/bin/mongod";
      shell "tar xvfz $downloadname.tgz $downloadname/bin/mongos";

      # move programs to directory and remove download dir and archive
      "$downloadname/bin".IO.rename($sversion);
      rmdir $downloadname;
      unlink "$downloadname.tgz";
    }
  }
}
