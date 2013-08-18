use 5.010001;
use ExtUtils::MakeMaker;
use Encode qw( find_encoding );

WriteMakefile(
    NAME              => 'OneEncoding::CORE',
    VERSION_FROM      => 'lib/OneEncoding/CORE.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/OneEncoding/CORE.pm', # retrieve abstract from module
       AUTHOR         => 'A. U. Thor <a.u.thor@a.galaxy.far.far.away>') : ()),
);

my $encoding = 'cp932';
$encoding = shift @ARGV if @ARGV;

my $setting = "t/TestSetting.pm";

print "Creating $setting with '$encoding'\n";
open $script, "> $setting" or die;

print $script <<TEST_SETTING;
package t::TestSetting;
use strict;
require Exporter;
our \@ISA = qw( Exporter );
our \@EXPORT = qw( \$ENCODING );

our \$ENCODING = '$encoding';

1;
TEST_SETTING

close $script;
print "Done\n";
print "If you wish to change default encoding, retry with\nperl Makefile.PL ANOTHER_ENCODING\n";
print "Now you can make test\n";
