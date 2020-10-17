#!/usr/bin/perl -w
# ######################################################################
# Copyright (c) 2020 Ben Aveling.
# ######################################################################
# This script extracts deltas from time_series_19-covid .csv files
# and creates .dat files suitable for gnuplot
#
my $usage = q{Usage:
  perl plot.pl [-h] [pull] [delta[only]] [deaths[only]] [pop[min]] [aus|us]
  -h = this help
  pull = retrieve latest data
  delta = plot delta
  deltaonly = plot only delta
  deaths = plot deaths
  deathsonly = plot only deaths
  pop = plot by population (ignore countries with less than min pop)
  pop<min> = plot by population ignoring countries with less than <min> pp
  aus or us = plot for states in Australia or USA respectively
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

my $plot_cases;
my $plot_deaths;
my $plot_deaths_only;
my $plot_delta;
my $plot_delta_only;
my $plot_us;
my $plot_by_pop;
my $min_pop;

my %country_counts;
my %total;
my %names;

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
  orange=>7,
  white=>8,
);

sub init_palette()
{
  open my $PALETTE, '>', 'palette.gp' or die "Can't write palette.gp: $!";
print $PALETTE qq{
# set palette maxcolors 2
set palette maxcolors 8
set palette defined ( \\
   1 'red', \\
   2 'gold', \\
   3 'blue', \\
   4 'yellow', \\
   5 'green', \\
   6 'black', \\
   7 'orange', \\
   8 'white', \\

  unset label
  # replot
};
}

init_palette();


sub init_grid()
{
  my $tics=tics();;
  my @y12=('y');
  my $retval=qq{
    # #########
    # init_grid
    set grid xtics
    set grid mxtics
  };
  $retval.=qq{
    # tics = $tics
  };
  if($tics eq 'lhs_rhs'){
    push @y12, 'y2';
    $retval.=qq{
      set ytics nomirror
      set y2tics 
    };
  }else{
    $retval.=qq{
      set y2tics mirror
    };
  }
  foreach my $y (@y12){
    $retval.=qq{
    set format $y "%6.0f"
    set ${y}tics
    set grid ${y}tics
    set grid m${y}tics
    };
  }
  $retval.=qq{
    # init_grid
    # #########
  };
  $retval=~s/^ */  /mg;
  return $retval
}

sub init_gp($)
{
  my $country=shift;
  my $retval=qq{
    # set title "New confirmed cases/deaths per day"
    # set title "Confirmed cases"
    set xdata time
    # set xtics format "%a %d/%m"
    set xtics format "%d/%m"
    set key left
    set timefmt "%Y-%m-%d"
    # set xrange ["2020-07-25":"2020-08-18"]
    set xrange ["2020-02-20":"2020-09-30"]
    # set xrange [*:*]
    set yrange [0:*]
    set grid lt 1, lt 0 dt 2
    set term wxt background rgb "gray"
    load "palette.gp"
  };
  if($country eq 'china'){
    $retval=~s/set xrange.*/set xrange [*:*]/ or die;
  }
  if($country eq 'everyone'){
    $retval.="set key outside\n";
  }else{
    $retval.=qq{unset label\n  set key inside\n};
  }
  # $retval.= $plot_delta ? "set ytics\n" : "unset ytics\n";
  $retval=~s/^\s*//;
  return $retval;
}

my @cols=(1..4,5,6..8);

my %flags=(
  china=>[qw(red)],
  sweden=>[qw(yellow blue)],
  denmark=>[qw(red white red)],
  norway=>[qw(red white blue)],
  japan=>[qw(red)],
  italy=>[qw(green white red)],
  greece=>[qw(blue white)],
  iran=>[qw(red red white white green green)],
  spain=>[qw(red yellow yellow red)],
  portugal=>[qw(red green)],
  germany=>[qw(black yellow red)],
  belgium=>[qw(black yellow red)],
  netherlands=>[qw(orange white blue)],
  us=>[qw(red red white white blue blue)],
  us_ex_ny=>[qw(red white blue)],
  canada=>[qw(red white)],
  france=>[qw(blue white red)],
  south_korea=>[qw(red blue white black)],
  switzerland=>[qw(red white)],
  united_kingdom=>[qw(red blue white)],
  #ireland=>[qw(green)],
  ireland=>[qw(green white orange)],
  finland=>[qw(blue white)],
  singapore=>[qw(red white)],
  taiwan=>[qw(red red blue)],
  thailand=>[qw(red white blue blue white red)],
  australia=>[qw(green yellow)], # yellow or gold? 
  # australia=>[qw(red white blue)],
  brazil=>[qw(green yellow blue)],
  saudi_arabia=>[qw(green)],
  diamond_princes=>[qw(red)],
  new_zealand=>[qw(black white)],
  mexico=>[qw(green white red)],
  turkey=>[qw(red white red)],
  hungary=>[qw(red white green)],
  #new_york=>[qw(blue white orange)],
  #florida=>[qw(red white)],
  russia=>[qw(red)],
  india=>[qw(orange white green)],
  peru=>[qw(red white red)],
  ukraine=>[qw(yellow blue)],
  chile=>[qw(blue white white red red)],
  colombia=>[qw(yellow yellow blue red)],
  south_africa=>[qw(green black white gold red blue)],
  vietnam=>[qw(red yellow red)],
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
  return qq{$plot "$country.dat" using 1:2:5 }.axis().qq{ with lines $title lw 6 $other};
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

read_pop();

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

my $last_title_name;

my $num_flips=0;

sub reset_lhs_rhs(){
  $num_flips=0;
  #$lhs_rhs='lhs';
  #$tics='lhs';
}

sub lhs_rhs(){
  return ( ($num_flips%2) ? 'rhs' : 'lhs');
}

sub axis(){
  return ( ($num_flips%2) ? 'axis x1y2' : 'axis x1y1');
 }

sub tics(){
  return ( ($num_flips<2) ? 'lhs' : 'lhs_rhs' );
 }

sub flip_sides(){
  ++$num_flips;
}

sub unflip_sides(){
  --$num_flips;
}

sub mk_title($$$)
{
  # eg {title "$name - $confirmed cases (rhs)"};
  my $name=shift;
  my $message=shift;
  my $ignore=shift;
  my $title=" title \"";
  if($name ne $last_title_name){
    $title.="$name ";
    $last_title_name=$name;
  }
  $title.="- $message (".lhs_rhs().")\"";
  return $title;
}

sub strip_commas($)
{
  my $str=shift;
  $str=~s/,//g;
  return $str;
}

my $by_country;

sub read_csv($)
{
  my $series=shift || die;
  my $plot_region=$plot_us?'US':'global';
  my $csv_file="time_series_covid19_\l$series\_$plot_region.csv";
  open my $IN, $csv_file or die;
  my $headings=<$IN>;
  my @headings=map {fix_date($_)} split /,/, $headings;
  my $name_column=$by_country ? 0 : 1; # are we plotting country or region?
  my $first_column=5;
  if($plot_us){
    $name_column = 6; # us is different again
    $first_column = 13;
  }
  while(my $line=<$IN>){
    $line=~s/\r?\n//;
    $line=~s/"([^",]*), ([^",]*)"/$2 $1/g;
    $line=~s/"([^"]*,.*?)"/strip_commas($1)/ge;
    my @columns=split /,/, $line;
    if($by_country){
      next unless $columns[1] =~ /$by_country/i;
    }
    # print "plotting $columns[1].$columns[0]\n";
    # next if $columns[0] =~ /diamond.princess/i;
    my $name = $columns[$name_column];
    my $region = lc($name);
    $region=~s/ /_/g;
    $region=~s/\*//g;
    $name=~s/\*//g;
    $names{$region} = $name;
    # next unless $country =~ /Australia/;
    for my $i ($first_column..$#columns){
      my $count = $columns[$i]||0;
      $country_counts{$region}{$headings[$i]}{$series}+=$count;
      $country_counts{grand_total}{$headings[$i]}{$series}+=$count;
      if($plot_us && $region ne "new_york"){
        #$country_counts{"us_ex_ny"}{$headings[$i]}{$series}+=$count;
      }
    }
    $total{$region}{$series} += $columns[$#columns];
    $total{grand_total}{$series} += $columns[$#columns];
    if($plot_us && $region ne "new_york"){
      #$total{"us_ex_ny"}{$series} += $columns[$#columns];
    }
  }
  $names{grand_total} = "Total";
}

sub val_for($)
{
  my $region=shift;
  my $val=$total{$region}->{$plot_deaths_only?'Deaths':'Confirmed'};
  if($plot_by_pop && $pop{$region}){
    $val/=$pop{$region};
  }
  return $val;
}

sub cmp_region($$)
{
  my $a=shift;
  my $b=shift;
  #my $val_a=$total{$a}->{Confirmed};
  #my $val_b=$total{$b}->{Confirmed};
  #my $val_a=$total{$a}->{Deaths};
  #my $val_b=$total{$b}->{Deaths};
  if($plot_by_pop){
    if($pop{$a} && !$pop{$b}){
      return 1;
    }
    if(!$pop{$a} && $pop{$b}){
      return -1;
    }
  }
    #elsif(!$flags{$a} && $flags{$b}){
    #return -1;
    #}elsif($flags{$a} && !$flags{$b}){
    #return 1;
    #}elsif($$pop{$a} && $pop{$b}){
    #$val_a /= $pop{$a};
    #$val_b /= $pop{$b};
    #}
  my $val_a=val_for($a);
  my $val_b=val_for($b);
  return $val_a <=> $val_b;
}

my %units=(
  0 => "",
  -2 => " per hundred",
  2 => " hundred",
  -3 => " per thousand",
  3 => " thousand",
  -6 => " per million",
  6 => " million",
  -9 => " per billion",
  9 => " billion",
);

sub units($)
{
  my $n=shift;
  my $e=0;
  return 0 if $n==0;
  while($n>1){
    $n/=10;
    $e++;
  }
  while($n<1){
    $n*=10;
    $e--;
  }
  while(!$units{$e}){
    $n*=10;
    $e--;
    die if $e<-9;
  }
  my $unit=$units{$e};
  return sprintf(" (%.1f%s)",$n,$unit);
}

# ####
# MAIN
# ####

# die $usage if !@ARGV;
# this next line is useful on dos
# @ARGV = map {glob($_)} @ARGV;

# 2020-03-25 Source file has moved. 
# my $csv_file=shift || "time_series_19-covid-$chart_file.csv";

$names{us_ex_ny} = "US ex NY";

$by_country="";
$plot_cases=" cases";
$plot_deaths='';
$plot_deaths_only='';
$plot_delta='';
$plot_delta_only='';
$plot_us='';
$plot_by_pop='';
$min_pop=0;

foreach(@ARGV){
  if(m/^-h/){
    print $usage;
    exit
  }elsif(m/delta/){
    $plot_delta=" delta-cases";
    $plot_delta_only=" (only)" if m/only/;
  }elsif(m/deaths/){
    $plot_deaths=" deaths";
    if(m/only/){
      $plot_cases='';
      $plot_deaths_only=" (only)";
    }
  }elsif(m/pop/){
    $plot_by_pop=" by population";
    if(m/\d+.*/){
      $min_pop=eval $&;
      $plot_by_pop.=" (min ".units($min_pop).")";
    }else{
      $plot_by_pop.=" (no minimum pop)";
      
    }
  }elsif(m/pull/){
    system("git pull");
  }else{
    $by_country=$_;
    if(m/^aus$/){
      $by_country="australia";
    }elsif(m/^us/){
      $plot_us=1;
      $flags{"grand_total"} = $flags{"us"};
    }
  }
}
if($plot_by_pop){
  # $plot_cases=$plot_deaths=$plot_delta="";
}
print "plotting $by_country:",$plot_cases,$plot_deaths,$plot_delta,$plot_by_pop,"\n";

foreach my $series (qw(Confirmed Deaths)){
  read_csv($series );
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
    my $confirmed=$value->{Confirmed} || 0;
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
print $EVERYONE init_gp('everyone');

open my $SCATTER, ">", "scatter.dat";

my $everyone_plot="plot";
foreach my $c (0..$#order_by_country){
  my $country = $order_by_country[$c];
  # next unless $country =~ m/china|^us$|south.korea|italy/;
  # next unless $country =~ m/australia|singapore/;
  # next unless $total{$country}>=$threshold_count;
  my $name=$names{$country};
  my $pop=$pop{$country};
  $name ="UK" if($country eq "united_kingdom");
  my $tc = $total{$country};
  my $confirmed = $tc->{Confirmed};
  my $deaths = $tc->{Deaths};
  my $country_total = "$confirmed cases";
  my ($cc,$lc)=line_color($country,$c);
  foreach my $plot ("plot", "replot"){
    $last_title_name="-";
    reset_lhs_rhs();
    open my $COUNTRY, ">", "\L$plot-$country.gp";
    my $country_plot=$plot;
    print $COUNTRY init_gp($country);
    my $to_print="";
    my $by_pop="";
    if($plot_by_pop){
      next if !$pop{$country};
      my $pop=$pop{$country};
      $by_pop="/$pop*1e3";
    }
    if($plot_cases && !$plot_delta_only){
      my $cases_by_pop=$plot_by_pop ? "(\$2$by_pop)" : '2' ;
      my $caption = "$confirmed confirmed cases";
      $caption .= units($confirmed/$pop) if $by_pop;
      my $title = mk_title($name,$caption,"rhs");
      $to_print.=qq{$country_plot "$country.dat" using 1:$cases_by_pop$cc }.axis().qq{ with lines $title $lc lw 6\n};
      flip_sides();
      $country_plot="replot";
    }
    # ## Delta ## #
    # cases per day
    if(($plot_cases||!$plot_deaths) && $plot_delta){
      my $title = mk_title($name,"new cases per day","lhs");
      $to_print.=qq{$country_plot "$country.dat" using 1:(\$4$by_pop)$cc }.axis().qq{ with lines $title $lc lw 4\n};
      flip_sides();
      $country_plot="replot";
    }
    ### plot deaths ###
    my $ratio=$deaths?sprintf(" - %.2f%%",$deaths/$confirmed*100):'';
    if($plot_deaths){
      if(!$plot_delta_only){
        # my $deaths_col=$plot_by_pop ? "(\$3/$pop*1e6)" : '3' ;
        my $title=mk_title($name,"$deaths deaths$ratio","rhs");
        $to_print.=qq{$country_plot "$country.dat" using 1:(\$3$by_pop)$cc }.axis().qq{ with lines $title $lc dt 3 lw 6\n};
      flip_sides();
        $country_plot="replot";
      }
      if($plot_delta){
        my $dt="dt 3";
        my $axis="x1y1";
        my $lhrhs="lhs";
        if($plot_delta_only){
          $dt="" if ! $plot_cases;
          $axis="x1y2";
          $lhrhs="rhs";
          $to_print.=qq{#unset logscale\n};
        }
        # my $deaths_col=$plot_by_pop ? "(\$5/$pop*1e6)" : '5' ;
        my $title=mk_title($name,"deaths per day",$lhrhs);
        $to_print.=qq{$country_plot "$country.dat" using 1:(\$5$by_pop)$cc }.axis().qq{ with lines $title $lc $dt lw 2\n};
        flip_sides();
        $country_plot="replot";
      }
    }
    ### Plot per thousand ###
    if($plot_by_pop){
        $to_print.=qq{
          # set logscale y2 10
        } if($plot eq "plot");
        $to_print.=qq{
          # set logscale y 10
          # set yrange [1:]
          # set logscale y2 10
          # set y2range [1:]
          set format y "%.2f/K"
          set format y2 "%.2f/K"
          replot
        };
    }
    unflip_sides();
    print $COUNTRY init_grid();
    print $COUNTRY $to_print;

    last if($plot ne "plot");

    if(-e "palette-$country.gp"){
      print $COUNTRY qq{load "palette-$country.gp"\n};
    }

    if(
       ($by_country || ($pop && $pop>$min_pop))
       && $country ne "grand_total"
       && $max_lines-- > 0
    )
    {
      if($everyone_plot ne "plot"){
        $to_print =~ s/^ *plot/replot/;
      }
      print $EVERYONE $to_print,"\n"; 
      $everyone_plot="replot";
    }
    if($pop && $country ne "grand_total"){
      $name=~s/ /-/g;
      print $SCATTER "$name $confirmed $deaths $pop\n"
    }
  }
}
print $EVERYONE init_grid();

print STDERR "Done\n";
