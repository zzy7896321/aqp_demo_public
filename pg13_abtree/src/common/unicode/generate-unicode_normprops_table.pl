#!/usr/bin/perl
#
# Generate table of Unicode normalization "quick check" properties
# (see UAX #15).  Pass DerivedNormalizationProps.txt as argument.  The
# output is on stdout.
#
# Copyright (c) 2020, PostgreSQL Global Development Group

use strict;
use warnings;

my %data;

print
  "/* generated by src/common/unicode/generate-unicode_normprops_table.pl, do not edit */\n\n";

print <<EOS;
#include "common/unicode_norm.h"

/*
 * We use a bit field here to save space.
 */
typedef struct
{
	unsigned int codepoint:21;
	signed int	quickcheck:4;	/* really UnicodeNormalizationQC */
}			pg_unicode_normprops;
EOS

foreach my $line (<ARGV>)
{
	chomp $line;
	$line =~ s/\s*#.*$//;
	next if $line eq '';
	my ($codepoint, $prop, $value) = split /\s*;\s*/, $line;
	next if $prop !~ /_QC/;

	my ($first, $last);
	if ($codepoint =~ /\.\./)
	{
		($first, $last) = split /\.\./, $codepoint;
	}
	else
	{
		$first = $last = $codepoint;
	}

	foreach my $cp (hex($first) .. hex($last))
	{
		$data{$prop}{$cp} = $value;
	}
}

# We create a separate array for each normalization form rather than,
# say, a two-dimensional array, because that array would be very
# sparse and would create unnecessary overhead especially for the NFC
# lookup.
foreach my $prop (sort keys %data)
{
	# Don't build the tables for the "D" forms because they are too
	# big.  See also unicode_is_normalized_quickcheck().
	next if $prop eq "NFD_QC" || $prop eq "NFKD_QC";

	print "\n";
	print
	  "static const pg_unicode_normprops UnicodeNormProps_${prop}[] = {\n";

	my %subdata = %{ $data{$prop} };
	foreach my $cp (sort { $a <=> $b } keys %subdata)
	{
		my $qc;
		if ($subdata{$cp} eq 'N')
		{
			$qc = 'UNICODE_NORM_QC_NO';
		}
		elsif ($subdata{$cp} eq 'M')
		{
			$qc = 'UNICODE_NORM_QC_MAYBE';
		}
		else
		{
			die;
		}
		printf "\t{0x%04X, %s},\n", $cp, $qc;
	}

	print "};\n";
}
