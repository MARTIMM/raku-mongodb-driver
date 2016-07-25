#!/usr/bin/env perl6

use v6.c;

use Test;

use BSON::Document;

use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

#-------------------------------------------------------------------------------
class MdbMeta {

  #-----------------------------------------------------------------------------
  my class MdbTable {
  
#    has BSON::Document $!doc .= new;
#    has BSON::Document $!schema;

    #---------------------------------------------------------------------------
    method set( $A: :%fields) {

    }

    #---------------------------------------------------------------------------
    method read () {
    
    }

    #---------------------------------------------------------------------------
    method read-next () {
    
    }

    #---------------------------------------------------------------------------
    method write () {
    
    }

    #---------------------------------------------------------------------------
    method update () {
    
    }

    #---------------------------------------------------------------------------
    method delete () {
    
    }
  }

  #-----------------------------------------------------------------------------
  method gen-table-class (
    MongoDB::Database:D $db,
    MongoDB::Collection:D $cl,
    BSON::Document:D $schema

    --> MdbTable
  ) {

    # class $db-$cl is MdbTable {
    my $name = "$db.name()-$cl.name()";
    my $A := Metamodel::ClassHOW.new_type(:$name);
    $A.^add_parent( MdbTable, :!hides);

    $A.^add_attribute(
      Attribute.new(
        :name<$!db>,
        :type(MongoDB::Database),
        :package($A)
      )
    );

    $A.^add_attribute(
      Attribute.new(
        :name<$!cl>,
        :type(MongoDB::Collection),
        :package($name)
      )
    );

    $A.^add_attribute(
      Attribute.new(
        :name<$!schema>,
        :type(BSON::Document),
        :package($name)
      )
    );

#`{{}}
    # method set
    $A.^add_method(
      'BUILD',
      my submethod BUILD ( $A: ) {
say "Self: ", self;
say self.^attributes;
#        $self!schema = $schema;
#        self!db = $db;
        $!cl = $cl;
      }
    );

    # Make it so
    $A.^compose;

#`{{
    augment class $A {
      submethod BUILD ( ) {
say self.^name;
      }
    }
}}
    
say $A.^parents(:all).perl;
say $A.^attributes;
say $A.^methods;

    $A;
  }
}

my MongoDB::Client $client .= new(:uri<mongodb://:65010>);
my MongoDB::Database $db = $client.database('contacts');
my MongoDB::Collection $cl = $db.collection('address');

my BSON::Document $schema .= new: (
  street => [ 1, Str],
  number => [ 1, Int],
  city => [ 1, Str],
  zip => [ 0, Str],
  state => [ 0, Str],
  country => [ 1, Str],
);

my $table-class = MdbMeta.gen-table-class( $db, $cl, $schema);
is $table-class.^name, 'contacts-address', "class type is $table-class.^name()";

my $table = $table-class.new;

ok $table.^can('read'), 'table can read';
ok $table.^can('write'), 'table can write';

done-testing;
