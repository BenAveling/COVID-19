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
use Data::Dumper;
# print Dumper $data;
# use FindBin;
# use lib "$FindBin::Bin/libs";
# use Time::HiRes qw (sleep);
# alarm 10; 

# my $chart_file="Confirmed"; my $chart_title="Confirmed cases as % of population of country";
# my $chart_file="Confirmed"; my $chart_title="Confirmed cases";
# my $chart_file="Deaths"; my $chart_title="Confirmed deaths";
my $max_lines=10;

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

sub init_gp()
{
  return qq{
    # set title "\$chart_title"
    set xdata time
    # set key left
    set key inside left
    set timefmt "%Y-%m-%d"
    # set logscale y2 2
    # set logscale y2
    unset logscale
    # set xrange ["2020-02-01":"2020-04-30"]
    set xrange [*:*]
    #set y2range [.00001:100]
    set y2range [0:*]
    # set format y2 "%0.6f%%"
    unset ytics
    set y2tics mirror
    set grid xtics
    set grid mxtics
    set grid y2tics
    set grid my2tics
    set grid lt 0, lt 0 dt 2
    set term wxt background rgb "gray"
  };
}

my @cols=(1..4,5,6..8);

my %palette=(
  blue=>1,
  red=>2,
  green=>3,
  yellow=>4,
  gold=>5,
  black=>6,
  white=>7,
);

my %flags=(
  china=>[qw(red)],
  japan=>[qw(red)],
  italy=>[qw(green white red)],
  iran=>[qw(red red white white green green)],
  spain=>[qw(red yellow yellow red)],
  germany=>[qw(black yellow red)],
  us=>[qw(red red white white blue blue)],
  # us=>[qw(red white blue)],
  # us=>[qw(blue)],
  france=>[qw(blue white red)],
  south_korea=>[qw(red blue)],
  switzerland=>[qw(red white)],
  united_kingdom=>[qw(red blue white)],
  singapore=>[qw(red white)],
  taiwan=>[qw(red red blue)],
  australia=>[qw(green yellow)],
);

my %labels=(
  china=>["2020-02-04", 55000],
  italy=>["2020-03-12", 33000],
  south_korea=>["2020-03-20", 14250],
  singapore=>["2020-03-14", 140],
  japan=>["2020-03-16", 1200],
  united_kingdom=>["2020-03-23", 4000],
  australia=>["2020-03-22", 1020],
  us=>["2020-03-22", 22000],
  taiwan=>["2020-03-11", 70],
);

sub plot_country($$$@)
{
  my $plot=shift;
  my $country=shift;
  my $title=shift;
  my $other="@_";
  return qq{$plot "$country.dat" using 1:2:5 axis x1y2 with lines $title lw 6 $other};
  # return qq{$plot "$country.dat" using 1:2 axis x1y2 with lines $title lw 1 $other};
  # return qq{$plot "$country.dat" using 1:2 axis x1y2 with linespoints $title $other};
    # # total
    # $plot "$country.dat" using 1:2:2 with labels notitle
    # $plot "$country.dat" using 1:2 with lines title "$name - total"
    # # per day
    # $plot "$country.dat" using 1:3:3 with labels notitle
    # replot "$country.dat" using 1:3 with lines title "$name - per day"
    # plot "$country.dat" using 1:4:4 with labels notitle
    # replot "$country.dat" using 1:4 with lines title "$name"
}

my %pop;

sub read_pop
{
  open(my $POP,"country_population.txt") or die;
  while(<$POP>){
    next if m/^\s*#|^\s*$/;
    my @fields=split /\t/, $_;
    my $country=shift @fields or die "Not enough fields: '$_'";
    my $region=shift @fields or die "Not enough fields: '$_'";
    my $subregion=shift @fields or die "Not enough fields: '$_'";
    my $pop2018=shift @fields or die "Not enough fields: '$_'";
    my $pop2019=shift @fields or die "Not enough fields: '$_'";
    my $change=shift @fields or die "Not enough fields: '$_'";
    die "More fields than expected: $_" if @fields;
    $country=~s/\[.*\]//;
    $country=~s/ /_/g;
    $pop2019=~s/,//g;
    $pop{"\L$country"}=$pop2019;
  }
  $pop{"us"}=$pop{"united_states"};
  $pop{"holy_see"}=$pop{"vatican_city"};
  $pop{"timor-leste"}=$pop{"east_timor"};
  # print Dumper \%pop;
  # exit;
}

# ####
# MAIN
# ####

# die $usage if !@ARGV;
# this next line is useful on dos
# @ARGV = map {glob($_)} @ARGV;

# 2020-03-25 Source file has moved. 
# my $csv_file=shift || "time_series_19-covid-$chart_file.csv";

my %country_counts;
my %total;
my %names;

sub read_csv($){
  my $series=shift || die;
  my $csv_file="time_series_covid19_$series\_global.csv";
  open my $IN, $csv_file or die;
  my $headings=<$IN>;
  my @headings=map {fix_date($_)} split /,/, $headings;
  # read_pop();
  while(my $line=<$IN>){
    $line=~s/\r?\n//;
    $line=~s/"(.*), (.*)"/$2 $1/;
    my @columns=split /,/, $line;
    # next unless $columns[1] =~ /australia/i; next if $columns[0] =~ /diamond.princess/i;
    # my $country = lc(my $name = $columns[0]); # 0 = state, 1 = country
    my $country = lc(my $name = $columns[1]); # 0 = state, 1 = country
    $country=~s/ /_/g;
    $country=~s/\*//g;
    $name=~s/\*//g;
    $names{$country} = $name;
    # next unless $country =~ /Australia/;
    for my $i (5..$#columns){
      my $count = $columns[$i]||0;
      $country_counts{$country}{$headings[$i]}{$series}+=$count;
    }
    $total{$country}{$series} += $columns[$#columns];
  }
}

foreach my $series (qw(Confirmed Deaths)){
  read_csv($series );
}

foreach my $country ( sort keys %country_counts ){
  my @last=();
  my $c=0;
  my $flag=$flags{$country};
  # my $pop=$pop{$country};
  # if(!$pop){
    # warn "missing population data for $country\n";
    # }
  open(my $DAT,">","\L$country.dat") or die;
  my $values=$country_counts{$country};
  foreach my $date ( sort keys %{$values} ){
    my $value=$values->{$date};
    # my $prev = @last>6 ? $last[$#last-6] : 0;
    # my $prev = @last ? $last[$#last] : 0;
    # my $delta=$value-$prev;
    # my $ratio=$prev?sprintf("%.2f%%",($value/$prev-1)*100):'-';
    # push @last,$value;
    #$value = '-' if $value<3;
    my $colour="";
    if($flag){
      $colour=$palette{$flag->[($c++) % @{$flag}]};
    }
    print $DAT "$date\t$value->{Confirmed} $value->{Deaths} - $colour\n";
  }
}

my @order_by_country = reverse sort { $total{$a} <=> $total{$b} } keys %country_counts;
# my $threshold_country = $order_by_country[@order_by_country - 10];
# my $threshold_count = $total{$threshold_country};

open my $EVERYONE, ">", "plot-everyone.gp";
# my $plot="plot";
print $EVERYONE init_gp();
print $EVERYONE q{
set palette maxcolors 7
set palette defined ( \
  1 'blue', \
  2 'red', \
  3 'green', \
  4 'yellow', \
  5 'gold', \
  6 'black', \
  7 'white', \

  unset label
  set key outside left
};
# 5 'yellow')

#foreach my $country (sort keys %country_counts){

my $everyone_plot="plot";
foreach my $c (0..$#order_by_country){
  my $country = $order_by_country[$c];
  # next unless $country =~ m/china|^us$|south.korea|italy/;
  # next unless $country =~ m/australia|singapore/;
  # next unless $total{$country}>=$threshold_count;
  my $name=$names{$country};
  $name ="UK" if($country eq "united_kingdom");
  # my $title = $total{$country}>=$threshold_count? qq{title "$name (Total $total{$country})"} : "notitle";
  my $total = $total{$country};
  #FIXME
  #my $title = $total > 250 ? qq{title "$name (Total $total)"} : "notitle";
  my $title = qq{title "$name (Total $total)"};
  # my $title = $total > 250 ? qq{title "$name (Total $total/$pop{$country})"} : "notitle";
  # my $title = qq{title "$name"};
  #if($c<$max_lines){
  # if($country=~m/^(us|italy|south_korea|china|japan|taiwan|singapore|australia)$/){
  # if($country=~m/^(us|italy|south_korea|china|taiwan|singapore|australia|united_kingdom)$/)
  # if($country=~m/^(us|italy|germany|france|spain|south_korea|china|united_kingdom)$/)
  #if($country=~m/^(us|italy|south_korea|china|united_kingdom|australia)$/)
  #if($country=~m/^(china|north_korea|iran|italy|spain|us)$/)
  if($country=~m/^(italy|us)$/)
  {
    # my $to_print=plot_country($plot,$country,$title," dt ".(1+$c%5), " lc ",$cols[$c%7]);
    my $flag=$flags{$country};
    my $lc=" lc ";
    my $color_column="";
    if($flag){
      $lc.="palette";
      $color_column=":5";
    }else{
      $lc.=$cols[$c%8];
    }
    if($labels{$country}){
      my $x=$labels{$country}->[0];
      my $y=$labels{$country}->[1];
      my $r=$labels{$country}->[2]||0;
      #print $EVERYONE qq{set label "$name" at first "$x", second $y rotate by $r\n};
    }
    #if(!$pop{$country}){
    #warn "skipping $country\n";
    #next;
    #}
    # my $to_print=plot_country($everyone_plot,$country,$title,$lc);
    my $to_print=qq{$everyone_plot "$country.dat" using 1:2$color_column axis x1y2 with lines title "$name $total->{Confirmed} confirmed cases" lw 6 $lc\n};
    $everyone_plot="replot";
    $to_print.=qq{$everyone_plot "$country.dat" using 1:3$color_column axis x1y2 with lines title "$name $total->{Deaths} confirmed deaths" lw 6 $lc\n};
    # my $to_print=qq{$everyone_plot "$country.dat" using 1:(\$2/$pop{$country}*100)$color_column axis x1y2 with lines $title lw 6 $lc};
    print $EVERYONE $to_print,"\n"; 
  }
  foreach my $country_plot ("plot", "replot"){
    open my $COUNTRY, ">", "\L$country_plot-$country.gp";
    print $COUNTRY init_gp();
    print $COUNTRY qq{unset label\nset key inside left\n};
    # my $to_print=plot_country($country_plot,$country,$title);
    my $to_print=qq{$country_plot "$country.dat" using 1:2 axis x1y2 with lines $title lw 6\n};
    $to_print.=qq{replot "$country.dat" using 1:3 axis x1y2 with lines notitle lw 6\n};
    print $COUNTRY $to_print;
  }
}

print STDERR "Done\n";
