#`{{
  Testing;
    Username and password check init
    Create a user
    Drop a user
    Drop all users
    Users info
    Grant roles
    Revoke roles
    Update user
}}

use v6;
use Test;
use MongoDB::Connection;
use MongoDB::Database::Users;

BEGIN { @*INC.unshift( './t' ) }
use Test-support;

my MongoDB::Connection $connection = get-connection();

# Drop database first then create new databases
#
$connection.database('test').drop;

my MongoDB::Database $database = $connection.database('test');
my MongoDB::Database::Users $users .= new(:$database);

#-------------------------------------------------------------------------------
subtest {
  my Hash $doc = $users.create_user(
    :user('mt'),
    :password('mt++'),
    :custom_data({license => 'to_kill'}),
    :roles(['readWrite'])
  );

  ok $doc<ok>, 'User mt created';

  if 1 {
    $doc = $users.create_user(
      :user('mt'),
      :password('mt++'),
      :custom_data({license => 'to_kill'}),
      :roles(['readWrite'])
    );

    CATCH {
      when X::MongoDB::Database {
        ok .error-text eq 'User "mt@test" already exists', .error-text;
      }
    }
  }

  $doc = $users.drop_user(:user('mt'));
  ok $doc<ok>, 'User mt dropped';

}, "Test user management";

#-------------------------------------------------------------------------------
#
subtest {
  my Hash $doc;
  $users.set_pw_security(
    :min_un_length(5),
    :min_pw_length(6),
    :pw_attribs($MongoDB::Database::Users::PW-OTHER-CHARS)
  );

  if 1 {
    $doc = $users.create_user(
      :user('mt'),
      :password('mt++'),
      :custom_data({license => 'to_kill'}),
      :roles(['readWrite'])
    );

    CATCH {
      when X::MongoDB::Database {
        ok .error-text eq 'Username too short, must be >= 5', .error-text;
      }
    }
  }

  if 1 {
    $doc = $users.create_user(
      :user('mt-and-another-few-chars'),
      :password('mt++'),
      :custom_data({license => 'to_kill'}),
      :roles(['readWrite'])
    );

    CATCH {
      when X::MongoDB::Database {
        ok .error-text eq 'Password too short, must be >= 6', .error-text;
      }
    }
  }

  if 1 {
    $doc = $users.create_user(
      :user('mt-and-another-few-chars'),
      :password('mt++tdt'),
      :custom_data({license => 'to_kill'}),
      :roles(['readWrite'])
    );

    CATCH {
      when X::MongoDB::Database {
        ok .error-text eq 'Password does not have the proper elements',
           .error-text;
      }
    }
  }

  if 1 {
    $doc = $users.create_user(
      :user('mt-and-another-few-chars'),
      :password('mt++tdt0A'),
      :custom_data({license => 'to_kill'}),
      :roles(['readWrite'])
    );

    ok $doc<ok>, 'User mt-and-another-few-chars created';
  }

  $doc = $users.drop_user(:user('mt-and-another-few-chars'));
  ok $doc<ok>, 'User mt-and-another-few-chars dropped';

}, "Test username and password checks";

#-------------------------------------------------------------------------------
subtest {
  my Hash $doc;
  $users.set_pw_security(:min_un_length(2), :min_pw_length(2));
  $doc = $users.create_user(
    :user('mt'),
    :password('mt++'),
    :custom_data({license => 'to_kill'}),
    :roles(['readWrite'])
  );

  ok $doc<ok>, 'User mt created';

  $doc = $users.users_info(:user('mt'));
  my $u = $doc<users>[0];
  is $u<_id>, 'test.mt', $u<_id>;
  is $u<roles>[0]<role>, 'readWrite', $u<roles>[0]<role>;

  $doc = $users.update_user(
    :user('mt'),
    :password('mt+++'),
    :custom_data({license => 'to_heal'}),
    :roles([{role => 'readWrite', db => 'test1'},
            {role => 'dbAdmin', db => 'test2'}
           ]
          )
  );

  ok $doc<ok>, 'User mt updated';

  $doc = $users.users_info(:user('mt'));
  $u = $doc<users>[0];
  is $u<roles>[0]<role>, any(<readWrite dbAdmin>), $u<roles>[0]<role>;
  is $u<roles>[0]<db>, any(<test1 test2>), $u<roles>[0]<db>;
  is $u<roles>[1]<role>, any(<readWrite dbAdmin>), $u<roles>[1]<role>;
  is $u<roles>[1]<db>, any(<test1 test2>), $u<roles>[1]<db>;

  $doc = $users.grant_roles_to_user( :user('mt'), :roles(['dbOwner']));
  ok $doc<ok>, 'User roles mt updated';
  $doc = $users.users_info(:user('mt'));
  $u = $doc<users>[0];
  is $u<roles>.elems, 3, 'Now 3 roles defined';
  is $u<roles>[2]<role>, any(<readWrite dbAdmin dbOwner>), $u<roles>[2]<role>;
  is $u<roles>[0]<role>, any(<readWrite dbAdmin dbOwner>), $u<roles>[0]<role>;

  $doc = $users.revoke_roles_from_user(
    :user('mt'),
    :roles([{role => 'dbAdmin', db => 'test2'}])
  );
  ok $doc<ok>, 'User roles mt revoked';
  $doc = $users.users_info(:user('mt'));
  $u = $doc<users>[0];
  is $u<roles>.elems, 2, 'Now 2 roles left';
  is $u<roles>[0]<role>, any(<readWrite dbOwner>), $u<roles>[0]<role>;

  $doc = $users.drop_all_users_from_database();
  ok $doc<ok>, 'All users dropped';

  $doc = $users.users_info(:user('mt'));
  is $doc<users>.elems, 0, 'No users in database';
}, 'account info and drop all users';

#-------------------------------------------------------------------------------
# Cleanup
#
$connection.database('test').drop;

done();
exit(0);
