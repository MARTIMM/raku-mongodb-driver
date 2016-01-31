use v6;
use Test;
use Digest::MD5;

my Int $min-chars = 3000;

#-------------------------------------------------------------------------------
subtest {

  my $m = Digest::MD5.new;
  my $txt;
  for ^$min-chars { $txt ~= 'a'; };
  
  my $h;
  for ^10 -> $i {
    $txt ~= 'b';
    $h = $m.md5_hex($txt);
    is $txt.chars, $min-chars + $i + 1, "Text length = {$min-chars + $i}";
  }

}, "MD5 string length test";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);
