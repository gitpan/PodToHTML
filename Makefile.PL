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

