#!perl -T

use 5.008;
use strict;
use warnings 'all';

use Test::More;
use Test::Requires 0.02;

# Required modules for this test
test_requires 'File::Spec';
test_requires 'Test::Perl::Critic';

Test::Perl::Critic->import(
	'-profile' => File::Spec->catfile('xt', 'perlcriticrc'),
);

# Criticize code
all_critic_ok('ex/');
