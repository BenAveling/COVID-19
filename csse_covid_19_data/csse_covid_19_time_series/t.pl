#!/usr/bin/perl -w
# ######################################################################
# Copyright (c) 2020 Ben Aveling.
# ######################################################################
# This script ...
#
my $usage = qq{Usage:
  perl xxx.pl ...
};
# ######################################################################
# History:
# 2020-MM-DD Created. 
# ######################################################################

# ####
# VARS
# ####

use strict;
use autodie;

require 5.022; # lower would probably work, but has not been tested

# use Carp;
# use Data::Dumper;
# print Dumper $data;
# use FindBin;
# use lib "$FindBin::Bin/libs";
# use Time::HiRes qw (sleep);
# alarm 10; 

# ####
# SUBS
# ####

# ####
# MAIN
# ####

die $usage if !@ARGV;
# this next line is useful on dos
# @ARGV = map {glob($_)} @ARGV;

while(<>){
  print if m/sunflower|coffee|bacon|cherry|curr|coke|lamb/i
}

print STDERR "Done\n";

