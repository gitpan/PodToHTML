#!perl 
use Test;                              
use File::Compare;
my $target = "t/testpod.ps";
BEGIN { plan test => 2 };
use Pod::HTML_Elements;
my $parser = new Pod::HTML_Elements PostScript => 1;
ok(ref($parser),'Pod::HTML_Elements',"Could not create parser");
$parser->parse_from_file("t/testpod.pod",$target);
ok(-f $target,1,"PostScript file not created");
# Cannot easily compare as it has a date in it!
# ok(compare("t/testpod_r.ps",$target),1,"PostScript file not correct");
unlink($target);

