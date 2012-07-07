##
# name:      Parse::SQLOutput
# abstract:  Parse SQL table output
# author:    Ingy döt Net <ingy@ingy.net>
# license:   perl
# copyright: 2012

use 5.008003;
use strict;
use warnings;

use Mo 0 ();

package Parse::SQLOutput;
use Mo qw'default';

our $VERSION = '0.01';

has as => (default => sub { 'hoh' });
has header => (default => sub { 0 });
has key => (default => sub { '' });

# use XXX;
sub parse {
    my ($self, $text) = @_;
    my @lines = split /\r?\n/, $text;

    my @tables = ();

    while (@lines) {
        $_ = shift(@lines);
        next unless /^\+/;
        my $offset = 2;
        my $fields = [];
        for (/\+(\-+)/g) {
            my $length = length() - 2;
            push @$fields, [$offset, $length];
            $offset += $length + 3;
        }
        my $header = shift(@lines);
        for (@$fields) {
            push(@$_, $self->_get_field($header, $_));
        }
        my $table = [[map $_->[-1], @$fields]];
        shift(@lines);
        while (my $line = shift(@lines)) {
            last unless $line =~ /^\|/;
            push @$table, [
                map {
                    $self->_get_field($line, $_);
                } @$fields
            ];
        }
        push @tables, $self->format($table);
    }
    return @tables;
}

sub format {
    my ($self, $input) = @_;
    my $method = 'format_' . $self->as;
    die "'as' must be 'hoh' or 'hol' or 'loh' or 'lol'"
        unless $self->can($method);
    return $self->$method($input);
}

sub format_hoh {
    my ($self, $input) = @_;
    my $output = {};
    my $as = $self->as;
    my $header = shift @$input;
    my $pos = $self->_key_pos($header);
    $output->{''} = $header if $self->header;
    for my $row (@$input) {
        my $key = $row->[$pos];
        $output->{$key} =
            $as eq 'hoh' ?  { $self->_zip($header, $row) } :
            $as eq 'hol' ? $row : die;
    }
    return $output;
}
*format_hol = \&format_hoh;

sub format_lol {
    my ($self, $input) = @_;
    my $output = [];
    my $as = $self->as;
    my $header = shift @$input;
    push @$output, $header if $self->header;
    for my $row (@$input) {
        push @$output,
            $as eq 'loh' ?  { $self->_zip($header, $row) } :
            $as eq 'lol' ? $row : die;
    }
    return $output;
}
*format_loh = \&format_lol;

sub _get_field {
    my ($self, $line, $offsets) = @_;
    my $value = substr($line, $offsets->[0], $offsets->[1]);
    $value =~ s!^\s*(.*?)\s*$!$1!;
    return $value;
}

sub _key_pos {
    my ($self, $header) = @_;
    my $key = $self->key;
    return 0 unless length $key;
    for (my $i = 0; $i < @$header; $i++) {
        return $i if $key eq $header->[$i];
    }
    die "'$key' is an invalid key name";
}

sub _zip {
    my ($self, $header, $row) = @_;
    map {
        ($_, shift(@$row));
    } @$header;
}

1;

=head1 SYNOPSIS

    use Parse::SQLOutput;

    my $sql_table_output = ...
    my $data = Parse::SQLOutput->new(<options>)->parse($sql_table_output);

=head1 DESCRIPTION

This module can parse the pretty printed tables you get from SQL queries, into
Perl data structures. There are a few options depending on how you want the
data to be formatted.

NOTE: This has only been tested with simple MySQL output so far. Patches
welcome.

=head1 OPTIONS

This parser can return your data in various forms depending on your needs:

=over

=item ->new(as => 'hoh'|'hol'|'loh'|'lol')

Specify the form that the result should be formatted in. Hash-of-hash,
hash-of-list, list-of-hash or list-of-list. Default is 'hoh'.

=item ->new(header => 0|1)

Specify whether the header values should be returned. Default is 0. If the
result is a hash, the header will be in the key of C<''> (empty string).

=item ->new(key => 'key-name')

If the result is a 'hash', specify which column to use as the key of the hash.
The default is C<''>, which means to use the first column's name.

=back
