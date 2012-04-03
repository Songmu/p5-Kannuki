use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Kannuki',
    VERSION_FROM  => 'lib/Kannuki.pm',
    PREREQ_PM     => {
        'Kossy' =>  '0.07',
    },
    MIN_PERL_VERSION => '5.008001'
);

