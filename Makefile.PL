
use strict;
use warnings;



use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'Run command-line sessions to network appliances',
  'AUTHOR' => 'Oliver Gorwits <oliver@cpan.org>',
  'BUILD_REQUIRES' => {
    'Test::More' => '0'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'Net-Appliance-Session',
  'EXE_FILES' => [],
  'LICENSE' => 'perl',
  'NAME' => 'Net::Appliance::Session',
  'PREREQ_PM' => {
    'Carp' => '0',
    'Class::Accessor::Fast::Contained' => '0',
    'Class::Data::Inheritable' => '0',
    'Exception::Class' => '0',
    'Exporter' => '0',
    'FileHandle' => '0',
    'IO::Pty' => '0',
    'Net::Appliance::Phrasebook' => '1.2',
    'Net::Telnet' => '0',
    'POSIX' => '0',
    'Symbol' => '0',
    'UNIVERSAL::require' => '0'
  },
  'VERSION' => '2.111080',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



