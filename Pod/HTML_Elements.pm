package Pod::HTML_Elements;
use strict;
use Pod::Parser 1.061;       
use Pod::Links qw(link_parse);
use HTML::Element;
use HTML::Entities;
use HTML::AsSubs qw(h1 a li title);
use vars qw(@ISA $VERSION);
$VERSION = '0.04';
use base qw(Pod::Parser);  
use Data::Dumper;     

my $nbsp;              

sub begin_pod
{                 
 my $obj = shift;
 delete $obj->{'title'};
 my $html = HTML::Element->new('html');
 my $head = HTML::Element->new('head');
 my $body = HTML::Element->new('body');
 $html->push_content($head);
 $html->push_content($body);
 $obj->{'html'} = $html;
 $obj->{'body'} = $body;
 $obj->{'current'} = $body;
 $obj->{'head'} = $head;              
 if (defined $obj->{'Index'} and not defined $obj->{'index'})
  {
   $obj->{'index'} = HTML::Element->new('ul');
  }
}       

sub current 
{ 
 my $obj = shift;
 $obj->{'current'} = shift if (@_);
 return $obj->{'current'}; 
}          

sub body    { return shift->{'body'} }
sub head    { return shift->{'head'} }
sub html    { return shift->{'html'} }
 
sub make_elem
{
 my $tag = shift;
 my $attributes;
 if (@_ and defined $_[0] and ref($_[0]) eq "HASH") 
  {
   $attributes = shift;
  }            
 else 
  {
   $attributes = {};
  }
 my $elem = new HTML::Element $tag, %$attributes;
 $elem->push_content(@_);
 return $elem;
}

sub add_elem
{
 my $body = shift->current;
 my $elem = make_elem(@_);
 $body->push_content($elem);
 return $elem;
}

sub do_name
{
 my ($parser,$t) = @_;
 $t =~ s/(^\s+|\s+$)//g;
 $parser->{'title'} = $t;
 $parser->{'in_name'} = 0;
 $parser->head->push_content(title($t));
 my $i = $parser->{'index'};
 if (defined $i)
  {        
   my $links = $parser->{'Links'};              
   my $l = $links->relative_url($parser->{'Index'},$parser->output_file) if (defined $links);
   $i->push_content("\n",li(a({href => $l},$t)));
  }
}

sub verbatim 
{
 my ($parser, $paragraph, $line_num) = @_;    
 $parser->do_name($paragraph) if ($parser->{'in_name'});
 $parser->add_elem(pre => $paragraph);
}          

sub raw_text
{
 my $text = '';
 foreach (@{$_[0]})
  {
   $text .= (ref $_) ? raw_text($_->content) : $_;
  }
 return $text;
}                                 

sub textblock 
{
 my ($parser, $paragraph, $line_num) = @_;
 my @expansion = $parser->parse_to_elem($paragraph, $line_num);
 if ($parser->{'in_name'})
  {
   my $t = raw_text(\@expansion);
   $parser->do_name($t);
  }
 my $c = $parser->current;
 if ($c->tag eq 'dt')
  {                           
   $parser->current($c = $c->parent);           
   $parser->current($parser->add_elem('dd' => @expansion));   
  }
 else
  {
   $parser->add_elem(p => @expansion);
  }
}         

sub linktext
{                  
 my $parser = shift;
 my $links = $parser->{'Links'};
 return $links->relative_url($parser->output_file,$links->url(@_)) if (defined $links);
 return undef;
}

sub non_break
{             
 my $tree = shift;
 foreach ($tree->children)
  {
   if (ref $_)
    {
     non_break($_->parse_tree);
    }
   else
    {
     s/ /$nbsp/g;
    }
  }
}

my %seq = (B => 'b', I => 'i', C => 'code', 'F' => 'i', 'L' => 'a');
sub seq_to_element
{
 my ($parser, $cmd, $tree) = @_;
 my $t = $seq{$cmd};
 if ($t)
  {     
   my @args = walk_tree($parser,$tree);
   if ($cmd eq 'L')
    {
     my $txt = raw_text(\@args);
     my ($text,@where) = link_parse($txt);
     @args = ($text) if ($text ne $txt);
     my $link = @where == 1 ? $where[0] : $parser->linktext(@where); 
     unshift(@args, { href => $link } ) if defined $link;
    }
   return make_elem($t,@args);
  }
 if ($cmd eq 'E')
  {        
   # Assume only one simple string in the argument ...
   my @args = walk_tree($parser,$tree);
   my $s = raw_text(\@args);
   return chr($s) if $s =~ /^\d+$/;
   return decode_entities("&$s;"); 
  }
 return '' if ($cmd eq 'Z');
 if ($cmd eq 'S')
  {                    
   $nbsp = decode_entities('&nbsp;') unless defined $nbsp;
   non_break($tree);
   return walk_tree($parser,$tree);
  }
 return ("$cmd<",walk_tree($parser,$tree),'>');
}

sub walk_tree
{
 my ($parser,$tree) = @_;
 my @list = ();
 foreach my $seq ($tree->children)
  {
   if (ref($seq))
    {
     my $cmd  = $seq->cmd_name;
     my $tree = $seq->parse_tree;
     push(@list,seq_to_element($parser,$cmd,$tree));
    }
   else
    {
     push(@list,$seq);
    }
  }
 return @list;
}

sub parse_to_elem 
{
 my ($self,$text,$line_num) = @_;
 my $tree = $self->parse_text($text, $line_num);
 return walk_tree($self,$tree);
}


sub command 
{      
 my ($parser, $command, $paragraph, $line_num) = @_;
 my @expansion = $parser->parse_to_elem($paragraph, $line_num);
 if ($command =~ /^head(\d+)?$/)
  {                   
   my $rank = $1 || 3;
   $parser->current($parser->body);
   my $t = raw_text(\@expansion);
   $t =~ s/\s+$//;
   if ($t eq 'NAME' && !$parser->{'title'})
    {
     $parser->{in_name} = 1;
    }
   my $name = $parser->linktext($t);
   if ($name)
    {
     @expansion = make_elem('a',{ name => substr($name,1) } , @expansion ) if (defined $name);
    }
   if ($rank == 1)
    {
     if ($parser->{'last_head1'} && $parser->{'last_head1'} eq $parser->input_file)
      {
       $parser->add_elem("p");
       $parser->add_elem("hr");
      }
     $parser->{'last_head1'} = $parser->input_file;
    }
   $parser->add_elem("h$rank" => @expansion);
  }
 elsif ($command eq 'over')
  {
   $parser->current($parser->add_elem('ul'));
  }
 elsif ($command eq 'item')
  {                              
   my $expansion = shift(@expansion);
   my $c = $parser->current;
   unless ($c->tag =~ /^(ul|dl|ol|dd|dt)/)
    {       
     my $file = $parser->input_file;
     $parser->add_elem("h3" => $expansion, @expansion);
     return;
    }
   if ($expansion =~ /^\*\s+(.*)$/)
    {
     $parser->add_elem(li => "$1",@expansion);
    }
   elsif ($expansion =~ /^\d+(?:\.|\s+|\))(.*)$/ || 
          $expansion =~ /^\[\d+\](?:\.|\s+|\))(.*)$/
         )
    {                                    
     my $s = $1;
     $c->tag('ol') unless $c->tag eq 'ol';
     $parser->add_elem(li => $s,@expansion);
    }
   else
    {                           
     if ($c->tag eq 'dt')
      {
       my $e = make_elem('strong', $expansion, @expansion);
       $parser->add_elem('br' => $e);
      }
     else
      {
       if ($c->tag eq 'dd')                          
        {                                            
         $parser->current($c = $c->parent)           
        }                                            
       $c->tag('dl') unless $c->tag eq 'dl';         
       my $e = make_elem('strong', make_elem('p'), $expansion, @expansion);
       my $t = raw_text([$expansion]);               
       if (length $t)
        {
         my $name = $parser->linktext($t);                                        
         $e = make_elem('a',{ name => substr($name,1) } , $e ) if (defined $name);
        }
       $parser->current($parser->add_elem(dt => $e));
      }
    }
  }
 elsif ($command eq 'back')
  {
   my $c = $parser->current;
   $parser->current($c = $c->parent) if ($c->tag eq 'dd');
   if ($c->tag =~ /^(ul|ol|dl)/)
    {
     $parser->current($c->parent);
    }
  }
 elsif ($command eq 'pod')
  {

  }
 elsif ($command eq 'for')
  {
   my $f = $parser->input_file;
   my $t = raw_text(\@expansion);
   # warn "$f:for $t\n";
   my $c = $parser->current;
  }
 elsif ($command eq 'begin')
  {
   my $f = $parser->input_file;
   my $t = raw_text(\@expansion);
   warn "$f:begin $t\n";
   my $c = $parser->current;
  }
 elsif ($command eq 'end')
  {
   my $t = raw_text(\@expansion);
   my $c = $parser->current;
  }
 else
  {
   warn "$command not implemented\n";
   $parser->add_elem(p => "=$command ",@expansion);
  }
}         

sub end_pod
{
 my $parser = shift;

 $parser->add_elem("p");
 $parser->add_elem("hr");                                      
 unless ($parser->{'NoDate'})
  {
   $parser->add_elem("i", make_elem( font => { size => "-1" } , 
                                     "Last updated: ",scalar localtime));
  }
 my $html = $parser->html;
 if ($html)
  {
   my $fh = $parser->output_handle;
   if ($fh)
    { 
     if ($parser->{'PostScript'})
      {
       require HTML::FormatPS;
       my $formatter = new HTML::FormatPS
                    FontFamily => 'Times', 
                    HorizontalMargin => HTML::FormatPS::mm(15),
                    VerticalMargin => HTML::FormatPS::mm(20),
                    PaperSize  => 'A4';
       print $fh $formatter->format($html);
      }
     elsif ($parser->{'Dump'})
      {
       $Data::Dumper::Indent = 1;
       print $fh Dumper($html);
      }
     else
      {
       print $fh $html->as_HTML;
      }
    } 
   $html->delete;
  }
}      

sub write_index
{
 my $parser = shift;      
 my $ifile = $parser->{'Index'};
 if (defined $ifile)
  {my $fh = IO::File->new(">$ifile");
   if ($fh)
    { 
     my $html = HTML::Element->new('html');
     my $head = HTML::Element->new('head');
     my $body = HTML::Element->new('body');
     $html->push_content($head);
     $html->push_content($body);
     $body->push_content("\n",h1('Table of Contents'),$parser->{'index'},"\n");
     print $fh $html->as_HTML;
     $html->delete;
     $fh->close;
    }
  }
}

sub interior_sequence 
{
 die "Should not be called now";
}

1;
__END__

=head1 NAME

Pod::HTML_Elements - Convert POD to tree of LWP's HTML::Element and hence HTML or PostScript

=head1 SYNOPSIS

  use Pod::HTML_Elements;  

  my $parser = new Pod::HTML_Elements;
  $parser->parse_from_file($pod,'foo.html');

  my $parser = new Pod::HTML_Elements PostScript => 1;
  $parser->parse_from_file($pod,'foo.ps');

=head1 DESCRIPTION

B<Pod::HTML_Elements> is subclass of L<B<Pod::Parser>>. As the pod is parsed a tree of
B<L<HTML::Element>> objects is built to represent HTML for the pod.

At the end of each pod HTML or PostScript representation is written to 
the output file.   

=head1 BUGS

Parameter pass-through to L<HTML::FormatPS> needs to be implemented.

=head1 SEE ALSO 

L<perlpod>, L<Pod::Parser>, L<HTML::Element>, L<HTML::FormatPS>

=head1 AUTHOR

Nick Ing-Simmons E<lt>nick@ni-s.u-net.comE<gt>

=cut 

