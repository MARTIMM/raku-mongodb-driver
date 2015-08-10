#`{{
  Testing;
    database.create_user()              Create a new user
    database.drop_user()                Drop user
}}

use v6;
use Test;
use MongoDB::Connection;

my MongoDB::Connection $connection .= new();

# Drop database first then create new databases
#
$connection.database('test').drop;

my MongoDB::Database $database = $connection.database('test');
#-------------------------------------------------------------------------------
subtest {
  my Hash $doc = $database.create_user(
    :user('mt'),
    :password('mt++'),
    :custom_data({license => 'to_kill'}),
    :roles(['readWrite'])
  );

  ok $doc<ok>, 'User mt created';

  if 1 {
    $doc = $database.create_user(
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

  $doc = $database.drop_user(:user('mt'));
  ok $doc<ok>, 'User mt dropped';

}, "Test user management";

#-------------------------------------------------------------------------------
#
subtest {
  my Hash $doc;
  $database.set_pw_security(
    :min_un_length(5),
    :min_pw_length(6),
    :pw-attribs($MongoDB::Database::PW-OTHER-CHARS)
  );

  if 1 {
    $doc = $database.create_user(
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
    $doc = $database.create_user(
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

if 0 {
  if 1 {
    $doc = $database.create_user(
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
    $doc = $database.create_user(
      :user('mt-and-another-few-chars'),
      :password('mt++tdt0A'),
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

  $doc = $database.drop_user(:user('mt-and-another-few-chars'));
  ok $doc<ok>, 'User mt-and-another-few-chars dropped';
}

}, "Test username and password checks";

#-------------------------------------------------------------------------------
# Cleanup
#
$connection.database('test').drop;

done();
exit(0);
