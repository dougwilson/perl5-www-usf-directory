#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok('WWW::USF::Directory');
}

diag("Perl $], $^X");
diag("WWW::USF::Directory " . WWW::USF::Directory->VERSION);
