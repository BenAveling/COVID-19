#!/usr/bin/perl -w
# ######################################################################
# Copyright (c) 2020 Ben Aveling.
# ######################################################################
# This script extracts deltas from time_series_19-covid .csv files
# and creates .dat files suitable for gnuplot
#
my $usage = q{Usage:
  perl plot.pl [-d|delta] [-m|mortality] [country]
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

my %prev;

sub delta($$)
{
  my $thing=shift;
  my $quant=shift;
  my $delta="-";
  if(defined $prev{$thing}){
    $delta=$quant - $prev{$thing};
  }else{
    $delta='-';
  }
  $prev{$thing}=$quant;
  return $delta;
}

sub fix_date($)
{
  my $date=shift;
  $date =~ m{(\d+)/(\d+)/(\d+)} or return undef;
  return sprintf "20%02d-%02d-%02d",$3,$1,$2;
}

my %palette=(
  red=>1,
  gold=>2,
  blue=>3,
  yellow=>4,
  green=>5,
  black=>6,
  white=>7,
);

sub init_palette()
{
  open my $PALETTE, '>', 'palette.gp' or die "Can't write palette.gp: $!";
print $PALETTE qq{
set palette maxcolors 2
# set palette maxcolors 7
set palette defined ( \\
   1 'red', \\
   2 'gold', \\
   3 'blue', \\
   4 'yellow', \\
   5 'green', \\
   6 'black', \\
   7 'white', \\

  unset label
};
}

init_palette();

sub init_gp()
{
  return qq{
  # set title "New confirmed cases/deaths per day"
  # set title "Confirmed cases"
    set xdata time
    set key left
    set timefmt "%Y-%m-%d"
    # set logscale y2 10
    # set logscale y2 2
    unset logscale
    set xrange ["2020-02-20":"2020-04-20"]
    # set xrange ["2020-02-20":*]
    # set xrange [*:*]
    #suitable for logscale, whole of population
    set yrange [0:*]
    set y2range [0:*]
    #set y2range [.00001:100]
    #suitable for logscale, actual counts
    set y2range [1:*]
    #suitable for linear
    #set y2range [0:*]
    # set format y2 "%0.6f%%"
    set format y2 "%6.0f"
    # set ytics
    unset ytics
    # set y2tics mirror
    set y2tics nomirror
    set grid xtics
    set grid mxtics
    set grid y2tics
    set grid my2tics
    set grid lt 1, lt 0 dt 2
    set term wxt background rgb "gray"
    load "palette.gp"
  };
}

my @cols=(1..4,5,6..8);

my %flags=(
  china=>[qw(red)],
  sweden=>[qw(blue yellow)],
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
  # australia=>[qw(red white blue)],
  brazil=>[qw(green yellow blue)],
  saudi_arabia=>[qw(green)],
  diamond_princes=>[qw(red)],
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
    $pop{grand_total}+=$pop2019;
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

my $plot_country=undef;
# $plot_country="australia";
# my $plot_country="us";

my $plot_deaths=0;
my $plot_delta=0;

foreach(@ARGV){
  if(m/-d|delta/){
    $plot_delta=1;
  }elsif(m/-m|mort/){
    print ">> plot deaths\n";
    $plot_deaths=1;
  }else{
    print ">> plot deltas\n";
    $plot_country=$_;
  }
}

sub read_csv($){
  my $series=shift || die;
  my $csv_file="time_series_covid19_\l$series\_global.csv";
  open my $IN, $csv_file or die;
  my $headings=<$IN>;
  my @headings=map {fix_date($_)} split /,/, $headings;
  read_pop();
  while(my $line=<$IN>){
    $line=~s/\r?\n//;
    $line=~s/"(.*), (.*)"/$2 $1/;
    my @columns=split /,/, $line;
    my $name;
    if($plot_country){
      next unless $columns[1] =~ /$plot_country/i;
      # next if $columns[0] =~ /diamond.princess/i;
      $name = $columns[0]; # 0 = state
      print "'$plot_country' > '$columns[1]' > '$name'\n";
    }else{
      $name = $columns[1]; # 1 = country
    }
    my $region = lc($name);
    $region=~s/ /_/g;
    $region=~s/\*//g;
    $name=~s/\*//g;
    $names{$region} = $name;
    # next unless $country =~ /Australia/;
    for my $i (5..$#columns){
      my $count = $columns[$i]||0;
      $country_counts{$region}{$headings[$i]}{$series}+=$count;
      $country_counts{grand_total}{$headings[$i]}{$series}+=$count;
    }
    $total{$region}{$series} += $columns[$#columns];
    $total{grand_total}{$series} += $columns[$#columns];
  }
    $names{grand_total} = "Total";
}

foreach my $series (qw(Confirmed Deaths)){
  read_csv($series );
}

sub cmp_region($$)
{
  my $a=shift;
  my $b=shift;
  my $val_a=$total{$a}->{Confirmed};
  my $val_b=$total{$b}->{Confirmed};
  return $val_a <=> $val_b;
}

foreach my $country ( keys %country_counts ){
  #my @last=();
  my $c=0;
  my $flag=$flags{$country};
  %prev=();
  # my $pop=$pop{$country};
  # if(!$pop){
    # warn "missing population data for $country\n";
    # }
  open(my $DAT,">","\L$country.dat") or die;
  my $values=$country_counts{$country};
  # my $prev_confirmed;
  foreach my $date ( sort keys %{$values} ){
    my $value=$values->{$date};
    my $confirmed=$value->{Confirmed};
    my $deaths=$value->{Deaths};
    # my $prev = @last>6 ? $last[$#last-6] : 0;
    # my $prev = @last ? $last[$#last] : 0;
    # my $delta="-";
    my $delta_cases=delta('cases',$confirmed);
    my $delta_deaths=delta('deaths',$deaths);
    # $prev_confirmed=$confirmed;
    # my $ratio=$prev?sprintf("%.2f%%",($value/$prev-1)*100):'-';
    # push @last,$value;
    #$value = '-' if $value<3;
    my $colour="";
    if($flag){
      $colour=$palette{$flag->[($c++) % @{$flag}]};
    }
    # print "$confirmed='-' if($confirmed == $total{$country}->{Confirmed} && $delta == 0);\n";
    $confirmed='-' if($confirmed == $total{$country}->{Confirmed} && ($delta_cases eq '-' || $delta_cases == 0));
    print $DAT "$date\t$confirmed $deaths $delta_cases $delta_deaths $colour\n";
  }
}

my @order_by_country = reverse sort {cmp_region($a,$b)} keys %country_counts;

# my $threshold_country = $order_by_country[@order_by_country - 10];
# my $threshold_count = $total{$threshold_country};

open my $EVERYONE, ">", "plot-everyone.gp";
# my $plot="plot";
print $EVERYONE init_gp(),"set key outside\n";

#foreach my $country (sort keys %country_counts){
sub line_color($$)
{
  my $country=shift;
  my $c=shift;
  my $flag=$flags{$country};
  my $lc=" lc ";
  my $cc="";
  if($flag){
    $lc.="palette";
    $cc=":6";
  }else{
    $lc.=$cols[$c%8];
  }
  return ($cc,$lc);
}

my $everyone_plot="plot";
foreach my $c (0..$#order_by_country){
  my $country = $order_by_country[$c];
  # next unless $country =~ m/china|^us$|south.korea|italy/;
  # next unless $country =~ m/australia|singapore/;
  # next unless $total{$country}>=$threshold_count;
  my $name=$names{$country};
  $name ="UK" if($country eq "united_kingdom");
  my $tc = $total{$country};
  my $confirmed = $tc->{Confirmed};
  my $deaths = $tc->{Deaths};
  # my $country_total = "$confirmed confirmed cases, $deaths deaths";
  my $country_total = "$confirmed cases";
  my $title = qq{title "$name - $confirmed cases"};
  if($c<$max_lines && $country ne "grand_total")
  # if($country=~m/^(us|italy|south_korea|china|japan|taiwan|singapore|australia)$/)
  # if($country=~m/^(us|italy|south_korea|china|taiwan|singapore|australia|united_kingdom)$/)
  # if($country=~m/^(us|italy|germany|france|spain|south_korea|china|united_kingdom)$/)
  #if($country=~m/^(us|italy|south_korea|china|united_kingdom|australia)$/)
  #if($country=~m/^(china|north_korea|iran|italy|spain|us)$/)
  # if($plot_country || $country=~m/^(italy|us)$/)
  {
    # my $to_print=plot_country($plot,$country,$title," dt ".(1+$c%5), " lc ",$cols[$c%7]);
    my ($cc,$lc)=line_color($country,$c);
    if($labels{$country}){
      my $x=$labels{$country}->[0];
      my $y=$labels{$country}->[1];
      my $r=$labels{$country}->[2]||0;
      #print $EVERYONE qq{set label "$name" at first "$x", second $y rotate by $r\n};
    }
    ### Plot number of cases ###
    my $to_print=qq{$everyone_plot "$country.dat" using 1:2$cc axis x1y2 with lines title "$name $country_total" lw 6 $lc\n};
    # -- case v deaths --
    # $to_print=qq{unset xdata;$everyone_plot "$country.dat" using 2:3$cc axis x1y2 with lines title "$name $country_total" lw 6 $lc\n};
    $everyone_plot="replot";
    ### plot deaths ###
    # $to_print.=qq{$everyone_plot "$country.dat" using 1:3$cc axis x1y2 with lines title "$name $total->{Deaths} confirmed deaths" lw 6 $lc\n} if $plot_deaths;
    ### Plot relative to population ###
    if(0){
      if(!$pop{$country}){
        print "population of $country unknown\n";
      }else{
        $to_print=qq{$everyone_plot "$country.dat" using 1:(\$2/$pop{$country}*100)$cc axis x1y2 with lines $title lw 6 $lc};
      }
    }
    print $EVERYONE $to_print,"\n"; 
  }
  my ($cc,$lc)=line_color($country,$c);
  foreach my $country_plot ("plot", "replot"){
    open my $COUNTRY, ">", "\L$country_plot-$country.gp";
    print $COUNTRY init_gp();
    print $COUNTRY qq{unset label\nset key inside\n};
    # my $to_print=plot_country($country_plot,$country,$title);
    my $to_print=qq{$country_plot "$country.dat" using 1:2$cc axis x1y2 with lines $title $lc lw 6\n};
    ### plot deaths ###
    my $ratio=$deaths?sprintf(" - %.2f%%",$deaths/$confirmed*100):'';
    $to_print.=qq{replot "$country.dat" using 1:3$cc axis x1y2 with lines title "$deaths deaths$ratio (rhs)" $lc dt 3 lw 6\n} if $plot_deaths;
    # ## Delta ## #
    # cases per day
    if($plot_delta){
      $to_print=qq{$country_plot "$country.dat" using 1:4 axis x1y2 with boxes title "$name - new cases per day" lw 6\n};
    }
    # deaths per day
    # $to_print=qq{$country_plot "$country.dat" using 1:5 axis x1y2 with lines title "$name" lw 6\n};
    # ## Plot relative to population ## #
    if($plot_deaths){
      if(!$pop{$country}){
        print "population of $country unknown\n";
      }else{
        $to_print=qq{
        set logscale y2 10
        set y2range [0.0000001:100]
        set format y2 "%0.6f%%"
        plot "$country.dat" using 1:(\$2/$pop{$country}*100)$cc axis x1y2 with lines $title lw 6 $lc};
      }
    }
    print $COUNTRY $to_print;
  }
}

print STDERR "Done\n";
