use 5.004;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'     => 'PodToHTML',
    'EXE_FILES' => [qw(podtohtml)],
    'PMLIBDIRS'   => [qw(Pod)],
    'clean' => {FILES => "*% *.bak *.old Pod/*% t/html/*"},
    'linkext' => { LINKTYPE => ''},
    'dist'     => { COMPRESS => 'gzip -f9', SUFFIX => '.gz' },
    'VERSION_FROM' => 'Pod/HTML_Elements.pm',
);

package MY;

sub const_config
{
 my $self = shift;
 foreach my $name (grep /(%|\.(old|bak|q4))$/,keys %{$self->{PM}})
  {
   delete $self->{PM}->{$name};
  }
 return $self->SUPER::const_config;
}
