#`{{
  Testing;
}}

use v6;

use lib 't';
use Test-support;

use Test;
use MongoDB::Connection;
use UUID;
use Digest::MD5;
use BSON::Binary-old;

#-------------------------------------------------------------------------------
my MongoDB::Connection $connection = get-connection();
my MongoDB::Database $database = $connection.database('test');
$database.drop;

# Create collection and insert data in it!
#
my MongoDB::Collection $collection = $database.collection('cl1');
my BSON::Binary $gen-bin .= new(data => Buf.new(12 .. 20));

my UUID $uuid .= new(:version(4));
my BSON::Binary $uuid-bin .= new(
  :data($uuid.Blob),
  :type(BSON::C-UUID)
);

my BSON::Binary $md5-bin .= new(
  data => Digest::MD5.md5_buf('some text'),
  type => BSON::C-MD5
);

subtest {
  my Hash $d = {
    number => Num.new(110.345),                         # BSON 0x01
    name => 'Jan Klaassen',                             #      0x02
    doc  => { nick => 'Super Klaas'},                   #      0x03
    array => [ -1, 5, 2, 4, 5],                         #      0x04
    bingen => $gen-bin,                                 #      0x05/0x00
    binuuid => $uuid-bin,                               #      0x05/0x04
    binmd5 => $md5-bin,                                 #      0x05/0x05
  };

  $collection.insert($d);

  my $cursor = $collection.find();
  my $cc = $cursor.count;
  ok $cc > 0, 'Record inserted';
  
}, "Test all types of data";

#-------------------------------------------------------------------------------
# Cleanup
#
#$database.drop;

done-testing();
exit(0);
