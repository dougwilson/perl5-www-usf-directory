#!/usr/bin/perl

package Directory;

use 5.008;
use strict;
use warnings 'all';

use base 'CGI::Application';

use JSON 2.00; # The API was changed
use Try::Tiny;
use WWW::USF::Directory;

sub setup {
	my ($self) = @_;

	# Create a directory object for use later
	$self->{directory} = WWW::USF::Directory->new(
		include_faculty  => 1,
		include_staff    => 1,
		include_students => 0,
	);

	# Start in search mode, which is the only mode
	$self->start_mode('search');
	$self->run_modes(search => 'search');

	return;
}

sub search {
	my ($self) = @_;

	# Hold the results and response
	my (@results, $response);

	# Set the header to specity JSON
	$self->header_add(-type => 'application/json');

	try {
		# Search the directory
		@results = $self->{directory}->search(
			name => scalar $self->query->param('name'),
		);

		foreach my $result (@results) {
			# Change the ::Directory::Entry object into a hash of its attributes
			$result = _moose_object_as_hash($result);

			if (exists $result->{affiliations}) {
				$result->{affiliations} = [map {
					_moose_object_as_hash($_);
				} @{$result->{affiliations}}];
			}
		}

		# Return the JSON-encoded results to print
		$response = JSON->new->encode({
			results => \@results,
		});
	}
	catch {
		# Get the error
		my $error = $_;

		# Return a JSON with the error
		$response = JSON->new->encode({
			error   => "$error",
			results => [],
		});
	};

	# Return the response
	return $response;
}

sub _moose_object_as_hash {
	my ($object) = @_;

	# Convert a Moose object to a HASH with the attribute_name => attribute_value
	my $hash = { map {
		($_->name, $_->get_value($object))
	} $object->meta->get_all_attributes };

	return $hash;
}

1;

## no critic (Modules::ProhibitMultiplePackages)
package main;

use 5.008;
use strict;
use warnings 'all';

our $VERSION = '0.001';

# Start and tun the application
Directory->new->run();
