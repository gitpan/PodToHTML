package Pod::HTML_Elements;
use strict;
use Pod::Parser;       
use Pod::Links qw(link_parse);
use Pod::InputObjects;
use HTML::Element;
use HTML::Entities;
use HTML::AsSubs qw(h1 a li title);
use vars qw(@ISA $VERSION);
$VERSION = '0.03';
use base qw(Pod::Parser);  
use Data::Dumper;     

sub interpolate_list {
    my $self = shift;
    my($text, $end_re, $need_array) = @_;
    ## Set defaults for unspecified arguments
    $text   = ''   unless (defined $text);
    $end_re = '$'  unless ((defined $end_re) && (length $end_re));
    $need_array = wantarray  unless (defined $need_array);
    local $_;
    my @result = ();
    my $item = '';
    ## Keep track of a stack of sequences currently "in progress"
    my $seq_stack = $self->{_SEQUENCE_CMDS};
    my ($seq_cmd, $seq_arg, $end) = ('', '', undef);
    my $pod_sequence = undef;
    ## Parse all sequences until end-of-string or we match the end-regex
    while ((length $text)  &&  ($text =~ /^(.*?)(([A-Z])<|($end_re))/s)) {
        ## Append text before the match to the result
        push(@result, $item = $1);
        ## See if we matched an interior sequence or an end-expression
        ($seq_cmd, $end) = ($3, $4);
        ## Only text after the match remains to be processed
        $text = substr($text, length($1) + length($2));
        ## Was this the end of the sequence
        if (! defined $seq_cmd) {
            last  if ($end_re eq '$');
            (! defined $end)  and  $end = "";
            ## If the sequence stack is empty, this cant be the end because
            ## we havent yet seen a proper beginning. Keep looking.
            next if ((@{$seq_stack} == 0) && ($item .= $end));
           
            ## The following is a *hack* to allow '->' and '=>' inside of
            ## C<...> sequences (but not '==>' or '-->')
            if (($end eq '>') && (@{$seq_stack} > 0)) {
                my $top_cmd = $seq_stack->[-1]->cmd_name();
                ## Exit the loop if this was the end of the sequence.
                last unless (($top_cmd eq 'C') && ($item =~ /[^-=][-=]$/));
                ## This was a "false-end" that was really '->' or '=>'
                ## so we need to keep looking.
                $result[-1] .= $end  and  next;
            }
        }
        ## At this point we have found an interior sequence,
        ## we need to obtain its argument
        $pod_sequence = new Pod::InteriorSequence(
                           -name => $seq_cmd,
                        );
        push(@{$seq_stack}, $pod_sequence);

        if ($need_array)
         {
          $seq_arg = $pod_sequence->list($self->interpolate_list($text, '>', 1));
         }
        else
         {
          $pod_sequence->text($seq_arg = $self->interpolate_list($text, '>', 0));
         }

        ## Now process the interior sequence
        push(@result, $self->interior_sequence($seq_cmd, $seq_arg,
                                               $pod_sequence));
        pop(@{$seq_stack});
    }
    ## Handle whatever is left if we didnt match the ending regexp
    unless ((defined $end) && ($end_re ne '$')) {
        push(@result, $text);
        $result[-1] .= "\n"  if (($end_re eq '$') && (chop($text) ne "\n"));
        $text = '';
    }
    ## Modify the input parameter to consume the text that was
    ## processed so far.
    $_[0] = $text;
    ## Return the processed-text
    return  ($need_array) ? @result : join('', @result);
}

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
 if (@_)
  {      
   $obj->{'current'} = shift;
  }
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
 my ($parser, $paragraph) = @_;    
 if ($parser->{'in_name'})
  {
   $parser->do_name($paragraph);
  }
 $parser->add_elem(pre => $paragraph);
}          

sub textblock 
{
 my ($parser, $paragraph) = @_;
 my @expansion = $parser->interpolate_list($paragraph);
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

my %seq = (B => 'b', I => 'i', C => 'code', 'F' => 'i', 'L' => 'a');

sub interior_sequence 
{
 my ($parser, $seq_command, $seq_argument, $seq) = @_;
 my $t = $seq{$seq_command};
 if ($t)
  {  
   my @args = $seq->list;
   if ($seq_command eq 'L')
    {
     my $txt = raw_text($seq_argument);
     my ($text,@where) = link_parse($txt);
     @args = ($text) if ($text ne $txt);
     my $link = $parser->linktext(@where); 
     unshift(@args, { href => $link } ) if defined $link;
    }
   return make_elem($t,@args);
  }
 if ($seq_command eq 'E')
  {                                
   # Assume only one simple string in the argument ...
   my $s = $seq_argument->[0];
   return chr($s) if $s =~ /^\d+$/;
   return decode_entities("&$s;"); 
  }
 return '' if ($seq_command eq 'Z');
 if ($seq_command eq 'S')
  {                    
   $nbsp = decode_entities('&nbsp;') unless defined $nbsp;
   non_break($seq_argument);
   return $seq->list;
  }
 return ("$seq_command<",$seq->list,'>');
}

sub non_break
{            
 foreach (@{$_[0]})
  {
   if (ref $_)
    {
     non_break($_->content);
    }
   else
    {
     s/ /$nbsp/g;
    }
  }
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

sub command 
{      
 my ($parser, $command, $paragraph) = @_;
 my @expansion = $parser->interpolate_list($paragraph);
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

