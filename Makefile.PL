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
     PREREQ_PM => {
                   HTML::FormatPS => 0,
                   HTML::Element  => 0,
                   HTML::Entities => 0,
                   HTML::AsSubs   => 0,
                   Pod::Parser    => 0,
                  },
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
