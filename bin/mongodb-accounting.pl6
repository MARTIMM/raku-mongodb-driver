#!/usr/bin/env perl6

use v6;

use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Server;
use MongoDB::Server::Control;
use MongoDB::HL::Users;
use BSON::Document;

#-------------------------------------------------------------------------------
# allow switches after positionals. pinched from an early panda program.
@*ARGS = |@*ARGS.grep(/^ '-'/), |@*ARGS.grep(/^ <-[-]>/);

# set logging levels
modify-send-to( 'mongodb', :level(MongoDB::MdbLoglevels::Info));
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Error));

#-------------------------------------------------------------------------------
# start servers
sub MAIN (
  $server, Str :$conf-loc is copy = '.',
  Bool :$add = False, Bool :$del = False,
  Bool :$modpw = False, Bool :$modrole = False, Bool :$list = False,
  Int :$unlen = MongoDB::C-PW-MIN-UN-LEN,
  Int :$pwlen = MongoDB::C-PW-MIN-PW-LEN,
  Int :$pwsec = MongoDB::C-PW-LOWERCASE,
) {

  # check if an admin account is needed to do the administration
  note "\nAdmin name and password is needed when authentication is turned on";
  note "Admin must also have global access. Type return if not needed";
  my Str $admin-name = prompt "Admin account name: ";
  my Str $admin-passwd = prompt "Admin password: " if $admin-name;
  my Str $auth-input = '';
  $auth-input = "$admin-name:$admin-passwd\@"
    if ?$admin-name and ?$admin-passwd;

  # get the controller to get servers port number. then connect to the server
  my MongoDB::Server::Control $server-control .= new(
    :config-name<server-configuration.toml>, :locations[$conf-loc]
  );
  my Int $port-number = $server-control.get-port-number($server);
  my Str $hostname = $server-control.get-hostname($server);
#TODO url encoding
  my MongoDB::Client $client .=
     new(:uri("mongodb://$auth-input$hostname:$port-number"));

  ismaster($client);

  del-accounts($client) if $del;
  modpw-accounts($client) if $modpw;
  modrole-accounts($client) if $modrole;
  add-accounts( $client, $unlen, $pwlen, $pwsec) if $add;

  list-accounts($client) if $list;
}

#-------------------------------------------------------------------------------
sub add-accounts (
  MongoDB::Client $client, Int $unlen, Int $pwlen, Int $pwsec ) {

  my BSON::Document $doc;

#`{{
  $doc = $database.run-command: (usersInfo => 1,);
  if $doc<ok> == 0e0 {
    my Str $server = $client.uri-obj.host ~ ':' ~ $client.uri-obj.port;
    given $doc<code> {
      when 13435 {
        note "Server $server is started as a replica server",
             " but is not initialized as one";
      }

      default {
        note "Server $server returned an unknown error:\n";
        note "  Code: $doc<code>\n  Error: $doc<errmsg>";
        note "Returned document info: ", $doc.perl;
      }
    }

    note "No accounts can be added, exiting ...";
    return;
  }

  note "\nThere are {$doc<users>.elems} users defined";
  for $doc<users> -> $u {
    note "Account:\n  ", $u.perl;
  }
}}

  # loop inserting accounts
  loop {
    my Str $uname;
    my Str $passw;
    while !$uname or !$passw {
      note "Provide both username and password (repeats if any is empty)";
      $uname = prompt("What is the username: ");
      $passw = prompt("What is the password: ");
      $uname = '' if $uname ~~ m/ <[@:]> /;
      $passw = '' if $passw ~~ m/ <[@:]> /;
    }

    # database user roles on specific database
    my Str @user-roles = < read readWrite >;

    # normal admin roles on specific database except admin
    my Str @admin-roles = < dbAdmin dbOwner userAdmin >;

    # cluster roles on admin database
    my Str @cluster-roles = < clusterAdmin clusterManager clusterMonitor
                              hostManager
                            >;

    # backup and restore on admin database
    my Str @backup-roles = < backup restore >;

    # any database roles on admin database
    my Str @alldb-roles = < readAnyDatabase readWriteAnyDatabase
                            userAdminAnyDatabase dbAdminAnyDatabase
                          >;

    # Superuser roles on admin database
    my Str @super-roles = < dbOwner userAdmin userAdminAnyDatabase >;


    my Str $dbname;
    my Array $roles = [];

    # get roles and database names
    loop {

      note "Which set of roles do you want assign to the user?";
      my Str $role-set = prompt("user(U), admin(A), cluster(C), backup(B), all database(D) or superuser(S) roles: ");
      given $role-set.uc {
        when 'A' {
          $dbname = prompt("Which database does account use (not admin): ");
          if $dbname eq 'admin' {
            note "For this choice the admin database is not allowed";
            next;
          }

          my Str $dbrole = prompt("Choose one of @admin-roles[*]?: ");
          if $dbrole !~~ any(@admin-roles) {
            note "Role $dbrole not in the set of: @admin-roles[*]";
            next;
          }

          $roles.push: ( role => $dbrole, db => $dbname);
        }

        when 'B' {
          my Str $dbrole = prompt("Choose one of @backup-roles[*]?: ");
          if $dbrole !~~ any(@backup-roles) {
            note "Role $dbrole not in the set of: @backup-roles[*]";
            next;
          }

          $roles.push: $dbrole;
          #$roles.push: ( role => $dbrole, db => 'admin');
        }

        when 'C' {
          my Str $dbrole = prompt("Choose one of @cluster-roles[*]?: ");
          if $dbrole !~~ any(@cluster-roles) {
            note "Role $dbrole not in the set of: @cluster-roles[*]";
            next;
          }

          $roles.push: $dbrole;
          #$roles.push: ( role => $dbrole, db => 'admin');
        }

        when 'D' {
          my Str $dbrole = prompt("Choose one of @alldb-roles[*]?: ");
          if $dbrole !~~ any(@alldb-roles) {
            note "Role $dbrole not in the set of: @alldb-roles[*]";
            next;
          }

          $roles.push: $dbrole;
          #$roles.push: ( role => $dbrole, db => 'admin');
        }

        when 'S' {
          my Str $dbrole = prompt("Choose one of @super-roles[*]?: ");
          if $dbrole !~~ any(@super-roles) {
            note "Role $dbrole not in the set of: @super-roles[*]";
            next;
          }

          $roles.push: $dbrole;
          #$roles.push: ( role => $dbrole, db => 'admin');
        }

        when 'U' {
          $dbname = prompt("Which database does account use (not admin): ");
          if $dbname eq 'admin' {
            note "For this choice the admin database is not allowed";
            next;
          }

          my Str $dbrole = prompt("Choose one of @user-roles[*]?: ");
          if $dbrole !~~ any(@user-roles) {
            note "Role $dbrole not in the set of: @user-roles[*]";
            next;
          }

          #$roles.push: $dbname;
          $roles.push: ( role => $dbrole, db => $dbname);
        }

        default {
          note "Choice $role-set not recognized, please try again";
          next;
        }
      }

      my Str $yn = prompt "Any more roles for user $uname? [Y(es), n(o)]: ";
      last if $yn ~~ m:i/^ n | no $/;
    }

    my MongoDB::Database $database = $client.database('admin');
    my MongoDB::HL::Users $users .= new(:$database);
note "len, sec: $unlen, $pwlen, $pwsec";
    $users.set-pw-security(
      :min-un-length($unlen), :min-pw-length($pwlen), :pw-attribs($pwsec)
    );
    $doc = $users.create-user( $uname, $passw, :$roles);
    if $doc<ok> eq 1e0 {
      note "Creation of user '$uname' ok";
    }

    else {
      note "Creation of user '$uname' failed;\n",
           "  Code: $doc<code>\n  Message: $doc<errmsg>";
    }

    my Str $yn = prompt "Are there more accounts to create? [y(es), N(o)]: ";
    last unless $yn ~~ m:i/^ (y | yes ) $/;

    print "\n";
  }
}

#-------------------------------------------------------------------------------
sub modpw-accounts ( MongoDB::Client $client ) {

}

#-------------------------------------------------------------------------------
sub modrole-accounts ( MongoDB::Client $client ) {

}

#-------------------------------------------------------------------------------
sub del-accounts ( MongoDB::Client $client ) {

  loop {
    my Str $uname = prompt "User account to remove: ";
    my MongoDB::Database $database = $client.database('admin');
    my BSON::Document $doc = $database.run-command: (dropUser => $uname,);
    note "A: ", $doc.perl;
    if $doc<ok> == 1e0 {
      note "Account '$uname' is deleted";
    }

    else {
      note "Error deleting account '$uname'\n",
           "  Code: $doc<code>\n  Message: $doc<errmsg>";
    }

    my Str $yn = prompt "Are there more accounts to remove? [y(es), N(o)]: ";
    last unless $yn ~~ m:i/^ (y | yes ) $/;

    print "\n";
  }
}

#-------------------------------------------------------------------------------
sub list-accounts ( MongoDB::Client $client ) {

  my MongoDB::Database $database = $client.database('admin');
  my BSON::Document $doc = $database.run-command: (usersInfo => 1,);
=begin comment
note "R: ", $doc.perl;
R: BSON::Document.new((
  users => [
        BSON::Document.new((
      _id => "admin.marcel",
      user => "marcel",
      db => "admin",
      roles => [
                BSON::Document.new((
          role => "readWrite",
          db => "bib",
        )),
                BSON::Document.new((
          role => "readWrite",
          db => "bib",
        )),
      ],
    )),
  ],
  ok => 1e0,
))
=end comment

  print "\n";
  given $doc<users>.elems {
    when 0 {
      note "There are no users defined";
      return;
    }

    when 1 {
      note "There is 1 user defined";
    }

    default {
      note "There are {$doc<users>.elems} users defined";
    }
  }

  for @($doc<users>) -> $u {
    note qq:s:to/EOINFO/;
      Account:
        username:     $u<user>
        database:     $u<db>
        Roles:
    EOINFO

    for @($u<roles>) -> $r {
      note qq:s:to/EOINFO/;
            role:       $r<role>
            database:   $r<db>
      EOINFO
    }
  }
}

#-------------------------------------------------------------------------------
sub ismaster ( MongoDB::Client $client ) {

  my MongoDB::Database $database = $client.database('admin');
  my BSON::Document $doc = $database.run-command: (ismaster => 1,);
  note "\nServer status: ", $doc.perl;
  print "\n";
}
