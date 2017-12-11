#!/usr/bin/perl
#
# Author: V. Mullachery
# Copyright (c), 2017. All Rights Reserved
# Dec, 2017
#
# Reads an LDIF file and splits them into one file per LDIF entry, with each
# file sorted by entries in ascending alphabetical order of
# attribute names (objectclass, eTAccountContainer etc. etc.).
# For multivalued attributes, entries are further in sorted order of
# values. Certain attributes that are single valued yet contain application
# specific name-values, can be sorted in ascending order of  name-value
# combination. For e.g. 'eTADSpayload' of CA Provisioning Directory
# eTADSPayload (values separated by ';'):
#   buildingName:01:0013=%#eTBuilding%;businessCategory:01:0015=%#eTDepartment%
#
# Run:
#   perl split_sort_ldif.pl AccountTemplates/ProdAccountTemplate.ldif
#
# Output:
#   Folder called 'SPLITFILES' contain individual dn entry
#   Each of the entry file has it's space replaced by '__'
#
use Net::LDAP::LDIF;
use Net::LDAP::Entry;

#
# Output folder
#
$prefix = "SPLITFILES";

unless(stat($prefix)) {
  mkdir ($prefix);
}

#
# Attributes with sortable list data, with separator
#
my %sortableAttributes = (
  "eTADSpayload" => ";",
);
$infile = shift @ARGV;
$ldif = Net::LDAP::LDIF->new($infile, 'r', onerror => 'undef');

while(not $ldif->eof()) {
  $entry = $ldif->read_entry();
  if ($ldif->error()) {
    print "Error msg: ", $ldif->error(), "\n";
    print "Error lines:\n", $ldif->error_lines(), "\n";
  } else {
    my @attributes = $entry->attributes(nooptions => 1);
    @attributes = sort @attributes;
    # Filename is based on DN
    my $outfilename = $entry->dn();
    $outfilename =~ s/ /__/g;
    $outfilename = $prefix.'/'.$outfilename;
    open $outfile, '>', $outfilename or die "Unable to open file: $outfilename, for writing\n";
    print $outfile "dn: ".$entry->dn()."\n";
    foreach my $attr (@attributes) {
      my @values = $entry->get_value($attr, alloptions => 0);
      @values = sort @values;
      foreach my $val (@values) {
        if (defined $sortableAttributes{$attr}) {
          my @split_array = split($sortableAttributes{$attr}, $val);
          @split_array = sort @split_array;
          $val = join($sortableAttributes{$attr}, @split_array);
        }
        print $outfile $attr.": ".$val."\n";
      }
    }
  }
}
$ldif->done();
