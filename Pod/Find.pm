package Pod::Find;     
use Exporter;
use File::Find;

@ISA = qw(Exporter);
@EXPORT = qw(find_pods contains_pod);

use strict;
use vars qw(%seen_file @pod_files);

sub find_pods
{
 local %seen_file;
 local @pod_files;
 find( \&pod_finder, @_);
 return @pod_files;
}

sub pod_finder
{
 unless ($seen_file{$File::Find::name})
  {
   my $is_pod = 0;                        
   if (/\.(?:pm|pod|pl)$/i || (-f $_ && -x _ && -T _))
    {                                     
     $is_pod = contains_pod($_)           
    }                                     

   push(@pod_files,$File::Find::name) if ($seen_file{$File::Find::name} = $is_pod); 
   
   if (-d $_)
    {
     if (/^(\d+\.[\d_]+)$/)
      {
       unless (eval "$1" == $])
        {
         $File::Find::prune = 1;
         warn "perl$] skipping $File::Find::name/...\n";
         return;
        }
      }
    }
  }         
}    

sub contains_pod
{  
 my $file = shift;
 local $/ = '';        
 my $pod = 0;
 if (open(POD,"<$file"))
  {
   local $_;  
   while (<POD>)
    {         
     if ($pod = /^=head\d\s/)
      {
       last; 
      }      
    }         
   close(POD);
  }
 else
  {
   warn "Cannot open $file:$!\n";
  }
 return $pod;
}


1;
__END__
