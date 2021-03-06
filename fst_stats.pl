#!/usr/bin/perl

#fst_stats.pl by Megan Supple
#created 11 Mar 2012
#last modified 16 August 2013
#
#script to calculate sliding window Fst and baseline Fst with jackknife confidence intervals from per position Fst
#usage fst_stats.pl InputFstFile.txt WindowSize StepSize MinPropSites MinPropIndivs
#	InputFstFile.txt is the fst output file from fasta2popgen.pl
#		contig, position, pop1#genoed, pop2#genoed, s1, s2, fst
#	WindowSize is the size of the sliding window
#	StepSize is the size of the step when moving the sliding window
#	MinPropSites is the minimum proportion of markers needed to calculate Fst at a window
#	MinPropIndivs is the minimum proportion of individuals of each population needed to use a site



use lib $ENV{PERL5LIB};
 
use strict; 
use warnings;
use Getopt::Long;
use Data::Dumper;

my $usage = "Usage: fst_stats.pl [options] <InputFstFile.txt> <WindowSize> <StepSize> <MinPropSites> <MinPropIndivs> <BootReps>
arguments (required):
	<InputFstFile.txt> is per position fst from fasta2popgen.pl
	<WindowSize> is the size of the sliding window
	<StepSize> is the size of the step when moving the sliding window
	<MinPropSites> is the minimum proportion of markers needed to calculate Fst at a window
	<MinPropIndivs> is the minimum proportion of individuals of each population needed to use a site
	<BootReps> is the number of bootstrap replicates to do (required only for boot option)
options:
	-jack	calculate a jackknife n-1 confidence interval for the contig
	-boot	calculate a bootstrap confidence interval for the contig
";

my $jackknife;
my $bootstrap;

GetOptions (	"jack" => \$jackknife,
		"boot" => \$bootstrap,	);

die "$usage" unless (@ARGV >= 5);

#read in command line arguments
my ($infst,$windowSize,$stepSize,$minProp, $minPropInds, $BootReps)=@ARGV;

#open input file and output file for sliding window fst and baseline fst
open(INFST, $infst)||die "can't open input fst file. $!\n";
my $outfile="slidingFst_" . $windowSize . "x" . $stepSize . "x" . $minProp . "x" . $minPropInds .".txt";
open(OUTFST, ">$outfile");
open(BASE, ">baseline.txt");

#print input parameters to output file
print OUTFST "####################\n";
print OUTFST "#input fst file=$infst\n";
print OUTFST "#window size=$windowSize\n";
print OUTFST "#step size=$stepSize\n";
print OUTFST "#minimum proportion of sites=$minProp\n";
print OUTFST "#minimum proportion of individual=$minPropInds\n";
print BASE "#input fst file=$infst\n";

#read header info from input file and write to output file
my $pop1n; my $pop2n;

my $line=<INFST>; print OUTFST "$line";#read in header border
$line=<INFST>; print OUTFST "$line";	#read in population 1 sample size
	chomp $line;
	my @entry=split("=",$line);
	$pop1n=$entry[1];
$line=<INFST>; print OUTFST "$line";	#read in population 1 sample list
$line=<INFST>; print OUTFST "$line";	#read in population 2 sample size
        chomp $line;
	@entry=split("=",$line);
        $pop2n=$entry[1];
$line=<INFST>; print OUTFST "$line";	#read in population 2 sample list
$line=<INFST>; print OUTFST "$line";	#read in header border
$line=<INFST>;				#read column header

print "n1=$pop1n and n2=$pop2n\n";
print OUTFST "contig\tposition\ts1\ts2\tFst\n";
print BASE "contig\ts1\ts2\tlowCI\tbaseline_Fst\thighCI\n";

print "calculating sliding window Fst\n";

#declare variables to track window
my $window_start=1;
my $window_end=$windowSize;

#declare other variable
my $contig;
my $fst;
my $mid_pos;
my @current_set=();	#an array of arrays holding the current set of markers
my $contig_s1=0;
my $contig_s2=0;	#tracks s1 and s2 for the current contig
my @jack_set=();	#set of all usable sites for jackknifing to get CI

#process input fst file until EOF
while($line=<INFST>)
	{
	  #break up line into component parts
	  my @entry=split(" ", $line);
	  $contig=$entry[0];
	  my $pos=$entry[1];

	  #add to baseline s1 and s2
	  #if enough individuals, add it to current marker set
          if($entry[2]>=$minPropInds*$pop1n && $entry[3]>=$minPropInds*$pop2n)
         	{
	  	  $contig_s1+=$entry[4];
	  	  $contig_s2+=$entry[5];  
		  push (@jack_set, [@entry]);
		}

	  #calculate sliding window Fst
	  #determine if current entry is in the window
	  if ($pos>=$window_start && $pos<=$window_end)
		{
		  #marker is in window
		  #if enough individuals, add it to current marker set
		  if($entry[2]>=$minPropInds*$pop1n && $entry[3]>=$minPropInds*$pop2n)
			{
			  push (@current_set, [@entry]);
			}
		}
	  else
		{
	  	  while ($pos<$window_start || $pos>$window_end)
			{
			  #marker is not in window, need to calculate Fst windows until it is in window		  			
		  	  #calculate Fst from previous window if there are enough markers, otherwise print NAs
			  if (@current_set<$windowSize*$minProp)
				{
				  $mid_pos=int($window_start+.5*($windowSize-1));
                        	  print OUTFST "$contig\t$mid_pos\tNA\tNA\tNA\n";
				}
			  else
				{
				  #calc fst by dividing sum of s1 by sum of s2
				  #sum s1 and s2
				  my $sum_s1=0;
				  my $sum_s2=0;
				  for (my $i=0;$i<@current_set;$i++)
					{
					  $sum_s1+=$current_set[$i][4];
					  $sum_s2+=$current_set[$i][5];
					}
				  my $fst=eval{$sum_s1/$sum_s2};

				  #calc mid position
				  $mid_pos=int($window_start+.5*($windowSize-1));
				  #print results to outfile	
				  if (defined $fst) {print OUTFST "$contig\t$mid_pos\t$sum_s1\t$sum_s2\t$fst\n";}
					else {print OUTFST "$contig\t$mid_pos\tNA\tNA\tNA\n";}
				}	
 
			  #reset current window
			  $window_start+=$stepSize;
			  $window_end=$window_start+$windowSize-1;
			  #reset current marker set by removing elements that are not in new window
			  for (my $i=0;$i<@current_set;$i++)
				{
				  #look at each element to see if it is in new window
				  if ($current_set[$i][1]<$window_start || $current_set[$i][1]>$window_end)
					{
					  #not in new window so remove from current set
					  splice(@current_set, $i, 1); 					  
					  #removed an entry so need to reindex
					  $i--; 
					}
				}
			}

	  	  #marker is now in current window so push into current array if enough samples
                  if($entry[2]>=$minPropInds*$pop1n && $entry[3]>=$minPropInds*$pop2n)
                        {
                          push (@current_set, [@entry]);
                        }
		}
	}


#after EOF calculate final fst window
#calculate Fst from previous window
#if there are enough markers, calc Fst
if (@current_set<$windowSize*$minProp)
	{
          $mid_pos=int($window_start+.5*($windowSize-1));
          print OUTFST "$contig\t$mid_pos\tNA\tNA\tNA\n";
	}
else
        {
          #calc fst by dividing sum of s1 by sum of s2
          #sum s1 and s2
          my $sum_s1=0;
          my $sum_s2=0;
          for (my $i=0;$i<@current_set;$i++)
  		{
                  $sum_s1+=$current_set[$i][4];
                  $sum_s2+=$current_set[$i][5];
                }
          $fst=eval{$sum_s1/$sum_s2};

          #calc mid position
          $mid_pos=int($window_start+.5*($windowSize-1));
          #print results to outfile
          if (defined $fst) {print OUTFST "$contig\t$mid_pos\t$sum_s1\t$sum_s2\t$fst\n";}
		else {print OUTFST "$contig\t$mid_pos\tNA\tNA\tNA\n";}
      	}


#after EOF calculate basline fst plus confidence intervals
#calculate baseline fst
my $baseline=eval{$contig_s1/$contig_s2};

#calculate CI
my @resample_set;
my @fst_dist;
my @fst_sort;
my $i_low;
my $i_high;

if ($jackknife || $bootstrap)
        {
	  my $locus=0;
          #iterate over sites
          for (my $i=0;$i<@jack_set;$i++)
            	{
                  #if position is variable put it in array for resampling
                  if ($jack_set[$i][5]!=0) 
			{
			  $resample_set[$locus][0]=$jack_set[$i][4];
			  $resample_set[$locus][1]=$jack_set[$i][5];
			  $locus++;
			}  
		}

       	  #print the number of variable sites
          print "$locus variable sites\n";
 

	  if($jackknife)
		{
		  print "jackknifing\n";
		  @fst_dist=();

	          #iterate over loci
		  for (my $i=0;$i<$locus;$i++)
			{        
		  	  #calculate fst for all sites but the current and add it to the distribution of fsts
                	  $fst_dist[$i]=eval{($contig_s1-$resample_set[$i][0])/($contig_s2-$resample_set[$i][1])};     	 	
	             	}
	
		  #if there are at least 2 variable sites to calc the confidence interval
	          if (defined $fst_dist[0])
        	     	{
                	  @fst_sort=sort(@fst_dist);
	                  $i_low=$locus*0.025;
        	          $i_high=$locus*0.975;
                	}
	  
	          print BASE "$contig\t$contig_s1\t$contig_s2\t$fst_sort[$i_low]\t$baseline\t$fst_sort[$i_high]\t(jackknife)\n";
		}


	  if($bootstrap)
		{
		  print "bootstrapping\n";
		  @fst_dist=();

		  #iterate over bootstrap replicates
		  for (my $rep=0;$rep<$BootReps;$rep++)
			{
			  my $s1=0; my $s2=0;

			  #resample same amount of loci
			  for (my $i=0;$i<$locus;$i++)
				{
			  	  #randomly sample loci and record s1 and s2
			  	  my $rand_num=int(rand($locus));
			  	  $s1+=$resample_set[$rand_num][0];
			  	  $s2+=$resample_set[$rand_num][1];
				}
			  #calculate fst
			  $fst_dist[$rep]=eval{$s1/$s2};
			}
		  
		  #if there are any bootstrap values, calculate the confidence interval
                  if (defined $fst_dist[0])
                        {
                          @fst_sort=sort(@fst_dist);
                          $i_low=$BootReps*0.025;
                          $i_high=$BootReps*0.975;
                        }
		  print BASE "$contig\t$contig_s1\t$contig_s2\t$fst_sort[$i_low]\t$baseline\t$fst_sort[$i_high]\t(bootstrap)\n";
		}
	}
else {print BASE "$contig\t$contig_s1\t$contig_s2\tNA\t$baseline\tNA\n";}
	
	

close INFST;
close OUTFST;
close BASE;
print "done!\n";










 












