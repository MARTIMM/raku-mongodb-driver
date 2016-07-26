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
    my $name = "$db.name.tc()::$cl.name.tc()";
    my $A := Metamodel::ClassHOW.new_type(:$name);
    $A.^add_parent( MdbTable, :!hides);

    my $db-attr = Attribute.new(
      :name<$!db>,
      :type(MongoDB::Database),
      :package($A)
    );

    my $cl-attr = Attribute.new(
      :name<$!cl>,
      :type(MongoDB::Collection),
      :package($name)
    );

    my $schema-attr = Attribute.new(
      :name<$!schema>,
      :type(BSON::Document),
      :package($name)
    );

    $A.^add_attribute($db-attr);
    $A.^add_attribute($cl-attr);
    $A.^add_attribute($schema-attr);

    # Need a new to bless the object after which the BUILD can access the
    # attributes
    #
    $A.^add_method(
      'new',
      my method new ( $A: ) {
say "Self: ", self;

        # Bless the object into the proper class
        "$name".bless;

        # Return proper object
        $A;
      }
    );

    $A.^add_method(
      'BUILD',
      my submethod BUILD ( ) {
say "Self: ", self;
#        $self!schema = $schema;
#        self!db = $db;
say $cl-attr.name;
        $db-attr.set_value( $A, $db);
        $cl-attr.set_value( $A, $cl);
        $schema-attr.set_value( $A, $schema);
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
    
say "0: $A.^parents(:all).perl()";
say "1: ", $A.^attributes.Str();
say "2: ", $A.^methods();

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
is $table-class.^name, 'Contacts::Address', "class type is $table-class.^name()";

my $table = $table-class.new;
say $table.^name;
say $table.^methods;

ok $table.^can('read'), 'table can read';
ok $table.^can('write'), 'table can write';

done-testing;
