use 5.008;
use strict;
use warnings 'all';

use Module::Build 0.31;

my $build = Module::Build->new(
	module_name => 'WWW::USF::Directory',
	license     => 'perl',
	dist_author => 'Douglas Christopher Wilson <doug@somethingdoug.com>',

	meta_merge => {
		resources => {
			homepage   => 'http://github.com/dougwilson/perl5-www-usf-directory/',
			repository => 'git://github.com/dougwilson/perl5-www-usf-directory.git',
		},
		no_index => {
			directory => [qw/inc t xt/],
		},
	},

	# Module that are required for tests in t/
	build_requires => {
		'Test::Exception'           => '0.03',
		'Test::More'                => '0.94',
		'Test::Override::UserAgent' => 0,
		'Test::Requires'            => '0.02',
		'URI::QueryParam'           => 0,
	},

	# Module that are required
	requires => {
		'perl'                      => '5.008001',
		'Carp'                      => 0,
		'English'                   => 0,
		'HTML::HTML5::Parser'       => '0.101',
		'List::MoreUtils'           => '0.07',
		'Moose'                     => '0.89',
		'MooseX::StrictConstructor' => '0.08',
		'MooseX::Types'             => '0.08',
		'MooseX::Types::Common'     => 0,
		'MooseX::Types::Email'      => 0,
		'MooseX::Types::Moose'      => 0,
		'MooseX::Types::URI'        => 0,
		'Net::SAJAX'                => '0.102',
		'Readonly'                  => '1.03',
		'namespace::clean'          => '0.04',
	},

	# Enable tests to be in multi-level directories
	recursive_test_files => 1,

	# Create a LICENSE file
	create_license => 1,

	test_files => 't/*.t xt/*.t',
);

$build->create_build_script;
