use v6;
use Test;

use BSON::Document;
use MongoDB::Header;

#-------------------------------------------------------------------------------
subtest {

  my BSON::Document $d .= new: ( doc => 'info');
  $d does MongoDB::Header;
  my Buf $b = $d.encode;

  is $b.elems, ([+] 4, 1, 4, 9, 1), 'Length of encoded buf is 19';

  my Buf $h = $d.encode-message-header( $b.elems, MongoDB::C-OP-QUERY);
  is $h.elems, 4*4, 'Size of header is 16';

  my $index = 0;
  my BSON::Document $dh = $d.decode-message-header( $h, $index);

  is $b.elems + 4*4, $dh<message-length>, 'Message length received 16';
  is $dh<request-id>, 0, "First request is $dh<request-id>";
  is $dh<op-code>, MongoDB::C-OP-QUERY, "Operation code is $dh<op-code>";

  my Buf $q-encode = $d.encode-query( 'users.files',
    :flags(MongoDB::C-QF-SLAVEOK +| MongoDB::C-QF-NOCURSORTIMOUT)
  );
  is $q-encode.elems,
     ([+] 4, 12, 4, 4, $b.elems, 4 * 4),
     "Total encoded size is {$q-encode.elems}";

#  my BSON::Document $d
}, "Header encode/decode";

#-------------------------------------------------------------------------------
subtest {
  my BSON::Document $d .= new: ( doc => 'info');
  $d does MongoDB::Header;

  my Buf $hand-made-buf .= new(
    0x29, 0x00, 0x00, 0x00,             # size 41 bytes
    0x01, 0x00, 0x00, 0x00,             # Req id = 1
    0x0A, 0x00, 0x00, 0x00,             # resp to 10
    0x01, 0x00, 0x00, 0x00,             # C-OP-REPLY

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
# Cleanup
#
done-testing;
exit(0);
