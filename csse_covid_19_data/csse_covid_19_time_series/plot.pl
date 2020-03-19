#!/usr/bin/perl -w
# ######################################################################
# Copyright (c) 2020 Ben Aveling.
# ######################################################################
# This script extracts deltas from time_series_19-covid .csv files
# and creates .dat files suitable for gnuplot
#
my $usage = qq{Usage:
  perl plot.pl
};
# ######################################################################
# History:
# 2020-03-18 Created. 
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

my %last=();
my %latest=();

sub delta($$){
  my $after=shift;
  my $before=shift;
  return $after - $before;
}

sub fix_date($)
{
  my $date=shift;
  $date =~ m{(\d+)/(\d+)/(\d+)} or return undef;
  return sprintf "20%02d-%02d-%02d",$3,$1,$2;
}

# ####
# MAIN
# ####

# die $usage if !@ARGV;
# this next line is useful on dos
# @ARGV = map {glob($_)} @ARGV;

# my $csv_file=shift || "time_series_19-covid-Confirmed.csv";
#my $csv_file=shift || "time_series_19-covid-Deaths.csv";
#my $chart_title="Deaths";
my $chart_file="Confirmed"; my $chart_title="Confirmed cases";
my $csv_file=shift || "time_series_19-covid-$chart_file.csv";
open my $IN, $csv_file or die;

my $headings=<$IN>;
my @headings=map {fix_date($_)} split /,/, $headings;

my %country_counts;
my %names;

my %total;

while(my $line=<$IN>){
  $line=~s/\r?\n//;
  $line=~s/"(.*), (.*)"/$2 $1/;
  my @columns=split /,/, $line;
  my $country = lc(my $name = $columns[1]);
  $country=~s/ /_/g;
  $country=~s/\*//g;
  $name=~s/\*//g;
  $names{$country} = $name;
  # next unless $country =~ /Australia/;
  for my $i (5..$#columns){
    my $count = $columns[$i]||0;
    $country_counts{$country}{$headings[$i]}+=$count;
  }
  $total{$country} += $columns[$#columns];
}
foreach my $country ( sort keys %country_counts ){
  my @last=();
  open(my $DAT,">","\L$country.dat") or die;
  my $values=$country_counts{$country};
  foreach my $date ( sort keys %{$values} ){
    my $value=$values->{$date};
    # my $prev = @last>6 ? $last[$#last-6] : 0;
    my $prev = @last ? $last[$#last] : 0;
    my $delta=$value-$prev;
    my $ratio=$prev?sprintf("%.2f%%",($value/$prev-1)*100):'-';
    print $DAT "$date\t$value $delta $ratio\n";
    push @last,$value;
  }
}

my @order_by_country = sort { $total{$a} <=> $total{$b} } keys %country_counts;
my $threshold_country = $order_by_country[@order_by_country - 10];
my $threshold_count = $total{$threshold_country};

open my $PLOT, ">", "plot-everyone.gp";
my $plot="plot";
#foreach my $plot (qw(plot replot)){
#open my $PLOT, ">", "\L$plot-$country.gp";
  print $PLOT qq{
    set title "$chart_title"
    set xdata time
      set key left
      set timefmt "%Y-%m-%d"
      #set logscale y
      #unset logscale y
      set xrange [*:*]
      set yrange [*:*]
  };
#foreach my $country (sort keys %country_counts){
foreach my $country (reverse @order_by_country){
  my $name=$names{$country};
    #next unless $country =~ m/china|^us$|south.korea|italy/;
    # next unless $country =~ m/australia|singapore/;
    my $title = $total{$country}>=$threshold_count? qq{title "$name (Total $total{$country})"} : "notitle";
    next unless $total{$country}>=$threshold_count;
    # my $title = qq{title "$name"};
    print $PLOT qq{
      # total
      # $plot "$country.dat" using 1:2:2 with labels notitle
      # $plot "$country.dat" using 1:2 with lines title "$name - total"
      $plot "$country.dat" using 1:2 with lines $title
      # per day
      # $plot "$country.dat" using 1:3:3 with labels notitle
      # replot "$country.dat" using 1:3 with lines title "$name - per day"
      # plot "$country.dat" using 1:4:4 with labels notitle
      # replot "$country.dat" using 1:4 with lines title "$name"
    };
    $plot="replot";
  #}
}

print STDERR "Done\n";
