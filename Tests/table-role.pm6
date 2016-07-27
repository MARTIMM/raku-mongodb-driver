#!/usr/bin/env perl6

use v6.c;

use BSON::Document;

use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

#-------------------------------------------------------------------------------
package MongoDB {

  #-----------------------------------------------------------------------------
  role MdbTableRole {

    has BSON::Document $!schema;
    has BSON::Document $!record;
    has MongoDB::Client $!client;
    has MongoDB::Database $!db;
    has MongoDB::Collection $!cl;

    #---------------------------------------------------------------------------
    method set( *%fields ) {

      # Define the record in the same order as noted in schema
      $!record .= new unless $!record.defined;
      for $!schema.keys -> $field-name {
        if %fields{$field-name}:exists {
          $!record{$field-name} = %fields{$field-name};
        }

        else {
          $!record{$field-name} = Nil unless $!record{$field-name}.defined;
        }
      }
    }

    #---------------------------------------------------------------------------
    method read () {

    }

    #---------------------------------------------------------------------------
    method read-next () {

    }

    #---------------------------------------------------------------------------
    method insert ( --> BSON::Document ) {

      $!db.run-command(
        BSON::Document.new: (
          insert => $!cl.name,
          documents => [
            $!record
          ]
        )
      );
    }

    #---------------------------------------------------------------------------
    method update () {

    }

    #---------------------------------------------------------------------------
    method delete () {

    }

    #---------------------------------------------------------------------------
    method check-record () {

      $!record .= new unless $!record.defined;
      for $!schema.keys -> $field-name {
        if %fields{$field-name}:exists {
          $!record{$field-name} = %fields{$field-name};
        }

        else {
          $!record{$field-name} = Nil unless $!record{$field-name}.defined;
        }
      }
    }
  }

  #-----------------------------------------------------------------------------
  class MdbTable does MdbTableRole {

    #---------------------------------------------------------------------------
    submethod BUILD (
      Str:D :$uri,
      Str:D :$db-name,
      Str:D :$cl-name,
      BSON::Document:D :$schema
    ) {

      $!client = MongoDB::Client.new(:$uri);
      $!db = $!client.database($db-name);
      $!cl = $!db.collection($cl-name);

      $!schema = $schema;
    }
  }

  sub gen-table-class (
    Str:D :$uri,
    Str:D :$db-name,
    Str:D :$cl-name,
    BSON::Document:D :$schema

    --> MongoDB::MdbTable
  ) is export {

    my $name = "$db-name.tc()::$cl-name.tc()";
#    my MongoDB::MdbTable $table .= new( :$uri, :$db-name, :$cl-name, :$schema);
#    $table.^set_name($name);

#`{{}}
    my $A := Metamodel::ClassHOW.new_type(:$name);
    $A.^add_parent( MongoDB::MdbTable, :!hides);
    $A.^compose;
    my MongoDB::MdbTable $table = $A.new(
      :$uri,
      :$db-name,
      :$cl-name,
      :$schema
    );

#    $table.rebless($A);
#    $A;

  }
}
