#!perl 
use Test;                              
plan test => 1;
mkdir("t/html",0777) unless -d "t/html";
my $code = system($^X,"-Mblib","podtohtml",'-q',
             '-d' => "t/html",-i => "t/html/index.html",
             "podtohtml","Pod");
ok($code,0,"Error from script");
