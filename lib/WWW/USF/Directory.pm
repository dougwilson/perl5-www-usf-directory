package WWW::USF::Directory;

use 5.008001;
use strict;
use warnings 'all';

###########################################################################
# METADATA
our $AUTHORITY = 'cpan:DOUGDUDE';
our $VERSION   = '0.001';

###########################################################################
# MOOSE
use Moose 0.89;
use MooseX::StrictConstructor 0.08;

###########################################################################
# MOOSE TYPES
use MooseX::Types::Moose qw(
	Bool
);
use MooseX::Types::URI qw(
	Uri
);

###########################################################################
# MODULE IMPORTS
use Encode;
use HTML::HTML5::Parser 0.03;
use List::MoreUtils 0.07;
use Net::SAJAX 0.102;
use Readonly 1.03;
use WWW::USF::Directory::Entry;
use WWW::USF::Directory::Exception;

###########################################################################
# PRIVATE CONSTANTS
Readonly my $FACULTY_BIT  => 1;
Readonly my $STAFF_BIT    => 2;
Readonly my $STUDENTS_BIT => 4;

###########################################################################
# ALL IMPORTS BEFORE THIS WILL BE ERASED
use namespace::clean 0.04 -except => [qw(meta)];

###########################################################################
# ATTRIBUTES
has 'directory_url' => (
	is  => 'rw',
	isa => Uri,

	documentation => q{This is the URL of the directory page were the requests are made},
	coerce  => 1,
	default => 'http://directory.acomp.usf.edu/',
);
has 'include_faculty' => (
	is  => 'rw',
	isa => Bool,

	documentation => q{This determines if faculty should be returned in the search results},
	default => 1,
);
has 'include_staff' => (
	is  => 'rw',
	isa => Bool,

	documentation => q{This determines if staff should be returned in the search results},
	default => 1,
);
has 'include_students' => (
	is  => 'rw',
	isa => Bool,

	documentation => q{This determines if students should be returned in the search results},
	default => 0,
);

###########################################################################
# METHODS
sub search {
	my ($self, %args) = @_;

	# Unwrap the name from the arguments
	my $name = $args{name};

	# Get the inclusion from the arguments
	my ($include_faculty, $include_staff, $include_students) =
		@args{qw(include_faculty include_staff include_students)};

	# Determine the inclusion of faculty
	if (!defined $include_faculty) {
		$include_faculty = $self->include_faculty
	}

	# Determine the inclusion of staff
	if (!defined $include_staff) {
		$include_staff = $self->include_staff;
	}

	# Determine the inclusion of students
	if (!defined $include_students) {
		$include_students = $self->include_students;
	}

	# Get the bit mask for the inclusion to send
	my $inclusion_bitmask = _inclusion_bitmask(
		include_faculty  => $include_faculty,
		include_staff    => $include_staff,
		include_students => $include_students,
	);

	# Make a SAJAX object
	my $sajax = Net::SAJAX->new(
		url => $self->directory_url->clone,
	);

	# Make a SAJAX call for the results HTML
	my $search_results_html = $sajax->call(
		function  => 'liveSearch',
		arguments => [$name, $inclusion_bitmask, q{}, q{}, q{}],
	);

	# Return the results
	return _parse_search_results_table($search_results_html);
}

###########################################################################
# PRIVATE FUNCTIONS
sub _clean_node_text {
	my ($node) = @_;

	# Make a copy of the node so modifications don't affect the original node.
	$node = $node->cloneNode(1);

	# Find all the line breaks
	foreach my $br ($node->getElementsByTagName('br')) {
		# Replace the line breaks with a text node with a new line
		$br->replaceNode($node->ownerDocument->createTextNode("\n"));
	}

	# Get the text of the node (make sure it is native UTF-8)
	my $text = Encode::encode_utf8($node->textContent);

	# Transform all the horizontal space into ASCII spaces
	$text =~ s{\h+}{ }gmsx;

	# Truncate leading and trailing horizontal space
	$text =~ s{^\h+|\h+$}{}gmsx;

	# Return the text
	return $text;
}
sub _clean_node_text_as_perl_name {
	my ($node) = @_;

	# Get the cleaned text as lowercase
	my $text = lc _clean_node_text($node);

	# Change all space into underscores
	$text =~ s{\p{IsSpace}+}{_}gmsx;

	# Return the text
	return $text;
}
sub _inclusion_bitmask {
	my (%args) = @_;

	# Create a default bitmask where nothing is selected
	my $bitmask = 0;

	if ($args{include_faculty}) {
		# OR in the faculty bit
		$bitmask |= $FACULTY_BIT;
	}

	if ($args{include_staff}) {
		# OR in the staff bit
		$bitmask |= $STAFF_BIT;
	}

	if ($args{include_students}) {
		# OR in the students bit
		$bitmask |= $STUDENTS_BIT;
	}

	# Return the bitmask
	return $bitmask;
}
sub _parse_search_results_table {
	my ($search_results_html) = @_;

	# Create a new HTML parser
	my $parser = HTML::HTML5::Parser->new;

	# Parse the HTML into a document
	my $document = $parser->parse_string($search_results_html);

	# Get the first heading level 3 element
	my $heading = $document->getElementsByTagName('h3')->get_node(1);

	if (defined $heading) {
		# Determine if the response thinks there are too many results
		if ($heading->textContent eq 'Too many results') {
			# Get the first paragraph element in the content
			my $paragraph = $document->getElementsByTagName('p')->get_node(1);

			if (defined $paragraph && $paragraph->textContent =~ m{(\d+) \s+ matches}msx) {
				# Store the max results from the regular expression
				my $max_results = $1;

				# Throw a TooManyResults exception
				WWW::USF::Directory::Exception->throw(
					class       => 'TooManyResults',
					message     => 'The search returned too many results',
					max_results => $max_results,
				);
			}
		}
		# Determine if the response had no results
		elsif ($heading->textContent eq '0 matches found') {
			# Return nothing
			return;
		}
	}

	# Get the first table in the response
	my $search_results_table = $document->getElementsByTagName('table')->shift;

	if (!defined $search_results_table) {
		# Don't know how to handle the response, so throw exception
		WWW::USF::Directory::Exception->throw(
			class         => 'UnknownResponse',
			message       => 'The response from the server did not contain a results table',
			response_body => $search_results_html,
		);
	}

	# Get all the table rows
	my $table_rows = $search_results_table->getChildrenByTagName('tbody')->shift
	                                      ->getChildrenByTagName('tr');

	# Get an array of table headers
	my @table_header = map { _clean_node_text_as_perl_name($_) }
		$table_rows->shift->getChildrenByTagName('td');

	# Get the table's content as array of entries
	my @results = map { _table_row_to_entry($_, \@table_header) }
		$table_rows->get_nodelist;

	return @results;
}
sub _table_row_to_entry {
	my ($tr_node, $table_header) = @_;

	# Get the row's text content as an array
	my @row_content = map { _clean_node_text($_) }
		$tr_node->getChildrenByTagName('td');

	# Make a hash with the headers as the keys
	my %row = List::MoreUtils::mesh @{$table_header}, @row_content;

	# Delete all keys with blank content
	delete @row{grep { length $row{$_} == 0 } keys %row};

	if (exists $row{given_name}) {
		# Remove vertical whitespace from the given name
		$row{given_name} =~ s{\h*\v+\h*}{ }gmsx;
	}

	# Make a new entry for the result
	my $entry = WWW::USF::Directory::Entry->new(%row);

	# Return the entry
	return $entry;
}

###########################################################################
# MAKE MOOSE OBJECT IMMUTABLE
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

WWW::USF::Directory - Access to USF's online directory

=head1 VERSION

Version 0.001

=head1 SYNOPSIS

  # Make a directory object
  my $directory = WWW::USF::Directory->new();

  # Search for people with the name "Jimmy"
  foreach my $entry ($directory->search(name => 'Jimmy')) {
      # Full Name: email@address
      print $entry->full_name, ': ', $entry->email_address, "\n";
  }

=head1 DESCRIPTION

This provides a way in which you can interact with the online directory at the
University of South Florida.

=head1 CONSTRUCTOR

This is fully object-oriented, and as such before any method can be used, the
constructor needs to be called to create an object to work with.

=head2 new

This will construct a new object.

=over

=item B<new(%attributes)>

C<%attributes> is a HASH where the keys are attributes (specified in the
L</ATTRIBUTES> section).

=item B<new($attributes)>

C<$attributes> is a HASHREF where the keys are attributes (specified in the
L</ATTRIBUTES> section).

=back

=head1 ATTRIBUTES

  # Set an attribute
  $object->attribute_name($new_value);

  # Get an attribute
  my $value = $object->attribute_name;

=head2 directory_url

This is the URL that commands are sent to in order to interact with the online
directory. This can be a L<URI> object or a string. This will always return a
L<URI> object.

=head2 include_faculty

This a Boolean of whether or not to include faculty in the search results. The
default is true.

=head2 include_staff

This a Boolean of whether or not to include staff in the search results. The
default is true.

=head2 include_students

This a Boolean of whether or not to include students in the search results. The
default is false.

=head1 METHODS

=head2 search

This will search the online directory and return an array of
L<WWW::USF::Directory::Entry> objects as the results of the search. This method
takes a HASH as the argument with the following keys:

=over 4

=item name

B<Required>. The name of the person to search for.

=item include_faculty

This a Boolean of whether or not to include faculty in the search results. The
default is the value of the L</include_faculty> attribute.

=item include_staff

This a Boolean of whether or not to include staff in the search results. The
default is the value of the L</include_staff> attribute.

=item include_students

This a Boolean of whether or not to include students in the search results. The
default is the value of the L</include_students> attribute.

=back

=head1 DEPENDENCIES

=over 4

=item * L<Encode>

=item * L<HTML::HTML5::Parser> 0.03

=item * L<List::MoreUtils> 0.07

=item * L<Moose> 0.89

=item * L<MooseX::StrictConstructor> 0.08

=item * L<MooseX::Types::URI>

=item * L<Net::SAJAX> 0.102

=item * L<namespace::clean> 0.04

=back

=head1 AUTHOR

Douglas Christopher Wilson, C<< <doug at somethingdoug.com> >>

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-www-usf-directory at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-USF-Directory>. I
will be notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

  perldoc WWW::USF::Directory

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-USF-Directory>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-USF-Directory>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-USF-Directory>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-USF-Directory/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2010 Douglas Christopher Wilson, all rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back
