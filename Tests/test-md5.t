use v6;
use Test;
use OpenSSL::Digest;

my Int $min-chars = 3000;

#-------------------------------------------------------------------------------
subtest "MD5 string length test", {

  my $txt;
  for ^$min-chars { $txt ~= 'a'; };

  my $h;
  for ^10 -> $i {
    $txt ~= 'b';
    $h = md5($txt.encode);
    is $txt.chars, $min-chars + $i + 1, "Text length = {$min-chars + $i}";
  }
}

#-------------------------------------------------------------------------------
# Cleanup
done-testing;
exit(0);
