package Pod::Links;      
use strict;            
use File::Basename;
use Carp;            
use Pod::Parser;
use vars qw(@ISA $VERSION @EXPORT_OK);
$VERSION = '1.00';
use base qw(Exporter Pod::Parser);
@EXPORT_OK = qw(link_parse);

sub link_parse
{                          
 my ($link,$sec) = @_;
 my ($section,$remote,$category);
 my $text = $link;
 $text = $1 if $link =~ s/^([^|]+)\|(?=.)//;
 return ($text,$link) if $link =~ m#[a-zA-Z]+://#;
 $link =~ s/\s+/ /g;
 $sec = {} unless defined $sec;
 if ((exists($sec->{$link}) && $link =~ /^(.*)$/) ||
     $link =~ /^"(.*)"$/ || $link =~ m#^/"?(.*?)"?$# ||
     ($link !~ m#/# && $link =~ /^(.*\s.*)$/))
  {
   $section = $1 || $link; 
  }                  
 elsif ($link =~ m#^([^/]+)(?:/"?(.*?)"?)?$#)
  {
   ($remote,$section) = ($1,$2);
   $category = $2 if ($remote =~ s/(\w+)\s*\((.*)\)$/$1/);
   # $section =~ s/\W+$// if defined $section;
  } 
 return ($text,$section,$remote,$category);
}

sub begin_pod
{
 my $parser = shift;
 $parser->{'links'} = {};
 $parser->{'sections'} = {}; 
 delete $parser->{'NAME'};
}


sub new
{
 my $parser = shift->SUPER::new(@_);
 $parser->{'documents'} = {};
 return $parser;
}                            

sub verbatim  
{ 
 my ($parser, $paragraph) = @_;
 if ($parser->{'inNAME'})
  {
   warn $parser->input_file.": verbatim NAME section!\n";
   $parser->{'NAME'} = $paragraph;
   $parser->{'inNAME'} = 0;
  }
}

sub textblock 
{ 
 my ($parser, $paragraph) = @_;
 if ($parser->{'inNAME'})
  {
   my $expansion = $parser->interpolate($paragraph);
   $parser->{'NAME'} = $expansion;
   $parser->{'inNAME'} = 0;
  }
}

sub command 
{                   
 my ($parser, $command, $paragraph) = @_;
 my $expansion = $parser->interpolate($paragraph);
 $expansion =~ s/(^\s+|\s+$)//g;
 $expansion =~ s/[\s\n]+/ /g;
 if ($command =~ /^(head\d)/ || ($command eq 'item' && $expansion !~ /^(\*|\d+\.)/))
  {   
   $parser->{'inNAME'} = ($command eq 'head1' && $expansion eq 'NAME');
   if ($command eq 'item' && $expansion =~ /\s/)
    {                                        
     $parser->{'sections'}{$expansion} |= 1;
     ($expansion) = split(/\s/,$expansion,2);
    }
   $parser->{'sections'}{$expansion} |= 1;
  }
}

sub interior_sequence 
{
 my ($parser, $seq_command, $seq_argument) = @_;
 if ($seq_command eq 'L')
  {
   my $expansion = $seq_argument;
   $expansion =~ s/(^\s+|\s+$)//g;
   $expansion =~ s/^[^|]+\|\s*//;
   $expansion =~ s/[\s\n]+/ /g;
   $parser->{'links'}{$expansion} = 0;
  }                
 elsif ($seq_command eq 'E')
  {
   return '>' if $seq_argument eq 'gt';
   return '<' if $seq_argument eq 'lt';
  }
 return $seq_argument; 
} 

sub documents
{
 my ($parser) = @_;
 return $parser->{'documents'};
}

sub names
{
 my ($parser) = @_;
 return sort keys %{$parser->{'documents'}};
}

sub url
{
 my ($parser,$sec,$name,$cat) = @_;
 my $url = '';
 return $url unless $sec || $name;
 if (defined($name) && length($name))
  {
   my $hash = $parser->{'documents'}{$name};
   return undef unless defined $hash->{'link'};
   $url .= $hash->{'link'};
  }
 if (defined $sec)
  {           
   $sec =~ s/[^A-Z0-9_]+/_/ig;
   $url .= "#$sec";
  }
 return $url;
}

sub relative_url
{        
 require URI::URL;
 my $parser = shift;
 my $source = URI::URL->newlocal(shift)->abs;
 my $url = shift;
 if ($url)
  {
   my $uo = URI::URL->new($url,$source)->abs;
   my $rel = $uo->rel->as_string;
   $url = $rel;
  }
 return $url;
}      


sub _attr
{
 my ($parser,$key,$name,$val) = @_;
 my $hash = $parser->{'documents'}{$name};
 $hash->{$key} = $val if (@_ > 3);
 return $hash->{$key};
}

foreach my $field (qw[pod name title sections link])
 {
  no strict 'refs';
  *{$field} = sub { shift->_attr($field,@_) }; 
 }

sub end_pod
{
 my ($parser) = @_;
 my $file = $parser->input_file();
 warn "$file\n" if $parser->{'Verbose'};
 my $name = $parser->{'NAME'};
 my $links = delete $parser->{'links'};
 my $sec   = delete $parser->{'sections'};
 my $documents = $parser->{'documents'};
 if (defined $name)
  {
   my ($doc,$title) = $name =~ /^\s*(.+?)\s+-+\s+([\s\S]*?)\s*$/;
   if (defined($doc))
    {     
     ($doc) = split(/\s*,\s*/,$doc,2) if ($doc =~ /,/);
     $title =~ s/\.\s[\s\S]*$//;
     if (exists $documents->{$doc})
      {        
       my $hash = $documents->{$doc};
       if (exists $hash->{'pod'})
        {                
         my $old = $hash->{'pod'};
         warn "`$doc' in $old and $file\n";
        }
       foreach my $section (keys %{$hash->{'sections'}})
        {               
         if (exists $sec->{$section})
          {
           $sec->{$section} |= $hash->{'sections'}{$section};
          }
         else
          {
           warn "No section '$section' in `$doc' $file\n";
          } 
        }
      }

     $documents->{$doc} = { name => $doc, title => $title, pod => $file, sections => $sec };

     foreach my $link (sort keys %$links)
      {
       my ($text,$section,$remote,$category) = link_parse($link,$sec);
       if (defined $remote)
        {
         unless (exists $documents->{$remote})
          {                         
           $documents->{$remote} = {'sections' => {}, 'refsfrom' => {}}; 
          }
         $documents->{$remote}->{'sections'}{$section} |= 4 if defined $section;
         $documents->{$remote}->{'refsfrom'}{$file}++;
        }
       elsif (defined $section)
        {
         $sec->{$section} |= 2;  # local ref 
        }
       else
        {
         warn "Strange link L<$link> in $file\n";
        }
      }
    }
   else
    {
     warn "Weird NAME '$name' in $file\n";
    }
  }
 else
  {
   warn "No NAME in $file\n";
  }
}      

sub check_links
{
 my $parser = shift;
 my $documents = $parser->{'documents'};
 foreach my $doc (sort keys %$documents)
  {
   my $sec = $documents->{$doc}->{'sections'};
   if (exists $sec->{'NAME'})
    {
     foreach my $section (sort keys %{$sec})
      {
       my $f = $sec->{$section};
       if (($f & 4) && !($f & 1))
        {
         warn "Links to $doc/$section but never seen\n";
        }
      }
    }
   else
    {
     my $who = $documents->{$doc}->{'refsfrom'};
     warn "Links to `$doc' but never seen\n";
     foreach my $file (sort keys %$who)
      {
       printf STDERR "%3d $file\n",$who->{$file};
      }
    }
  }
}      



1; 
__END__
