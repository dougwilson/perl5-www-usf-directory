use inc::Module::Install;

use Module::Install::AuthorRequires 0.02;

name     'WWW-USF-Directory';
all_from 'lib/WWW/USF/Directory.pm';
author   'Douglas Christopher Wilson <doug@somethingdoug.com>';
license  'perl';

# Resources
resources homepage   => 'http://github.com/dougwilson/perl5-www-usf-directory/';
resources repository => 'git://github.com/dougwilson/perl5-www-usf-directory.git';

# Modules that are required
requires
	'Carp'                      => 0,
	'Encode'                    => 0,
	'English'                   => 0,
	'HTML::HTML5::Parser'       => '0.03',
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
	'URI'                       => 0,
	'namespace::clean'          => '0.04';

# Modules that are required for tests in t/
test_requires
	'Test::Exception' => '0.03',
	'Test::More'      => 0;

# Modules that are required for tests in xt/
author_requires
	'Test::More'                      => 0,
	'Test::Requires'                  => '0.02';

# Enable tests to be in multi-level directories
tests_recursive;

# Write the provided classes in the META
auto_provides;

WriteAll;
