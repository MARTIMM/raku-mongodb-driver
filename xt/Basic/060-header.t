use v6.c;
use Test;

use BSON::Document;
use MongoDB;
use MongoDB::Header;

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $d .= new: ( doc => 'info');
  $d does MongoDB::Header;
  my Buf $b = $d.encode;

  is $b.elems, ([+] 4, 1, 4, 9, 1), 'Length of encoded buf is 19';

  ( my Buf $h,
    my Int $req-id
  ) = $d.encode-message-header( $b.elems, OP-QUERY);
  is $h.elems, 4*4, 'Size of header is 16';
  is $req-id, 0, 'First request encoding';

  my $index = 0;
  my BSON::Document $dh = $d.decode-message-header( $h, $index);

  is $b.elems + 4*4, $dh<message-length>, 'Message length received 16';
  is $dh<request-id>, 0, "First request is $dh<request-id>";
  is $dh<op-code>, OP-QUERY.value, "Operation code is $dh<op-code>";

  ( my Buf $q-encode, $req-id) = $d.encode-query(
    'users.files', :flags(C-QF-SLAVEOK.value +| C-QF-NOCURSORTIMOUT.value)
  );
  is $q-encode.elems,
     ([+] 4, 12, 4, 4, $b.elems, 4 * 4),
     "Total encoded size is {$q-encode.elems}";
  is $req-id, 1, 'Second request encoding';

#  my BSON::Document $d
}, "Header encode/decode";

#-------------------------------------------------------------------------------
subtest {
  my BSON::Document $d .= new: ( doc => 'info');
  $d does MongoDB::Header;

  my Buf $hand-made-buf .= new(
    0x29, 0x00, 0x00, 0x00,             # size 41 bytes
    0x01, 0x00, 0x00, 0x00,             # Req id = 1 (1st request in this test)
    0x0A, 0x00, 0x00, 0x00,             # resp to 10
    0x01, 0x00, 0x00, 0x00,             # OP-REPLY

    0x00, 0x00, 0x00, 0x00,             # no flags
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,             # cursor id = 0
    0x00, 0x00, 0x00, 0x00,             # cursor at 0
    0x01, 0x00, 0x00, 0x00,             # one document
    0x05, 0x00, 0x00, 0x00,             # empty document
    0x00
  );

  my BSON::Document $rd = $d.decode-reply($hand-made-buf);
  is $rd<message-header><request-id>, 1, 'Request id is 1';
  is $rd<number-returned>, 1, 'Number of docs is 1';
  is $rd<documents>[0].elems, 0, 'Empty document';

#  my BSON::Document $d
}, "query/reply";

#-------------------------------------------------------------------------------
subtest {
  my BSON::Document $d .= new;
  $d does MongoDB::Header;
  
  ( my Buf $encoded-get-more, my Int $req-id) = $d.encode-get-more(
    'testdb.testcoll',
    Buf.new( 0x02, 0x01, 0x03, 0x04, 0x03, 0x0f, 0x0e, 0x0a),
    :number-to-return(100)
  );
  is $req-id, 2, 'Third encoded request';

  my Buf $hand-made-buf .= new(
    0x30, 0x00, 0x00, 0x00,             # size 48 bytes
    0x02, 0x00, 0x00, 0x00,             # Req id = 2 (2nd request in this test)
    0x00, 0x00, 0x00, 0x00,             # resp to 0
    0xd5, 0x07, 0x00, 0x00,             # OP-GET-MORE

    0x00, 0x00, 0x00, 0x00,             # 0, reserved
    0x74, 0x65, 0x73, 0x74, 0x64, 0x62, # 'testdb.testcoll'
    0x2e, 0x74, 0x65, 0x73, 0x74, 0x63,
    0x6f, 0x6c, 0x6c, 0x00,
    0x64, 0x00, 0x00, 0x00,             # 100, number to return
    0x02, 0x01, 0x03, 0x04,
    0x03, 0x0f, 0x0e, 0x0a              # cursor id
  );

  is-deeply $encoded-get-more, $hand-made-buf, 'Encoded get more request';

#  my BSON::Document $d
}, "encoding get more";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing;
exit(0);
