use Getopt::Long;

my $help = '';
my $density_from = 3;
my $density_to = 5;
my $density_step = 0.5;

if (not GetOptions('help' => \$help, 'density_from=f' => \$density_from, 'density_to=f' => \$density_to, 'density_step=f' => \$density_step)) {
	print "Usage: perl $0 <Options> <Network File>\n";
	print "Try --help to find more about Options\n";
	exit;
}

if ($help) {
	print <<EOS;
Usage: perl $0 <Options> <Network File>
Options:
	--help            print this help message
	--density_from    clique size, start (3.0)
	--density_to      clique size, end (5.0)
	--density_step    clique size, step (0.5)
EOS
	exit;
}

if ($density_from > $density_to) {
	($density_from, $density_to) = ($density_to, $density_from);
}

if (@ARGV != 1) {
	print "Usage: perl $0 <Options> <Network File>\n";
	print "Try --help to find more about Options\n";
	exit;
}

open(FILE, $ARGV[0])|| die "can't open $ARGV[0] for $!\n";

my %PPI = ();
my %CC = ();

my $totale_ad = 0;
my $totaln_ad = 0;

while(my $line = <FILE>){
	chomp $line;
	$line=~m/^\s*(\S+)\s+(\S+)\s*/;
	my $nid1 = $1;
	my $nid2 = $2;
	if($nid1 ne $nid2){
		$PPI{$nid1}{$nid2} = 1;
		$PPI{$nid2}{$nid1} = 1;
	}
}

close FILE;

foreach my $nid1 ( keys %PPI ) {
	my $ncount = 0;
	my $ecount = 0;
	foreach my $nid2 ( keys %{ $PPI{$nid1} } ) {
		foreach my $tmp ( keys %{ $PPI{$nid1} } ) {
			if(exists $PPI{$nid2}{$tmp}){
				$ecount++;
			}
		}
		$ncount++;
	}
	$ecount = $ecount/2;
	$totaln_ad += $ncount*($ncount-1)/2;
	$totale_ad += $ecount;

	if($ncount>=2){
		$CC{$nid1} = [$ncount, (2*$ecount)/($ncount*($ncount-1))];
	}
}

my $edgepvalue = $totale_ad/$totaln_ad;

my %cccut = ();

foreach $nid1 ( keys %CC ) {
	for(my $i=$density_from; $i<=$density_to; $i=$i+$density_step){
		if(exists $cccut{$CC{$nid1}[0]}{$i}){
			push @{$CC{$nid1}}, $cccut{$CC{$nid1}[0]}{$i};
		}else{
			$cccut{$CC{$nid1}[0]}{$i} = ccc($edgepvalue, $i, $CC{$nid1}[0]);
			push @{$CC{$nid1}}, $cccut{$CC{$nid1}[0]}{$i};
		}
	}
}

%cccut = ();

my @nodes = keys %PPI;

automodule(\@nodes, 0);

sub automodule{
	my ($nodes_ref, $pvl, $tag) = @_;
	my %nodes = ();
	my %po = ();
	foreach my $node (@$nodes_ref) {
		$nodes{$node} = 1;
		if(exists $CC{$node} and $CC{$node}[1] ne 'NA'){
			if(($CC{$node}[$pvl+2] ne 'NA') and ($CC{$node}[1] >= $CC{$node}[$pvl+2])){
				$po{$node} = 0;
				$nodes{$node} = 3;
			}
		}
	}
	my $tagcount = 0;
	foreach my $nid ( keys %po ) {
		if($po{$nid}==0){
			$tagcount++;
			my @tmp = ();
			my @core = ();
			my %extend = ();
			my %total = ();
			$po{$nid} = 1;
			push @tmp, $nid;
			while(defined(my $node = shift @tmp)){
				push @core, $node;
				$total{$node} = 1;
				foreach my $nid2 ( keys %{ $PPI{$node} } ) {
					if(exists $nodes{$nid2}){
						if(not exists $po{$nid2}){
							foreach my $nid3 ( keys %{ $PPI{$node} } ) {
								if(exists $PPI{$nid2}{$nid3}){
									$extend{$nid2} = 1;
									$total{$nid2} = 1;
									$nodes{$nid2} = 2;
									last;
								}
							}
						}elsif($po{$nid2}==0){
							$po{$nid2} = 1;
							push @tmp, $nid2;
						}
					}
				}
			}

			foreach my $n (keys %nodes) {
				if( (not exists $total{$n}) and (not exists $po{$n}) ){
					my $f = 1;
					foreach my $nid2 ( keys %{ $PPI{$n} } ) {
						if(not exists $total{$nid2}){
							$f = 0;
							last;
						}
					}
					if($f==1){$extend{$n}=1; $total{$n}=1; $nodes{$n} = 2;}
				}
			}

			my $cn = $#core + 1;
			my $en = (keys %extend) + 0;
			my $tl = $pvl;
			while($tl>0){print "\t"; $tl--;}
			print "Module ID: ".$tag.$tagcount." (".($cn+$en)." nodes):\n";
			$tl = $pvl;
			while($tl>0){print "\t"; $tl--;}
			print "Core ($cn):\t".join("\t", @core)."\n";
			$tl = $pvl;
			while($tl>0){print "\t"; $tl--;}
			print "Extend ($en):";
			foreach $exnd ( keys %extend ) {
				print "\t$exnd";
			}
			print "\n";
			$tl = $pvl;
			while($tl>0){print "\t"; $tl--;}
			print "==============================\n";

			if($pvl<int(($density_to-$density_from)/$density_step)){
				my @nextlevel = keys %total;
				automodule(\@nextlevel, $pvl+1, $tag.$tagcount.".");
			}
		}
	}
	if($pvl==0){
		my $rc = 0;
		my @tmp = ();
		foreach my $n (keys %nodes) {
			if($nodes{$n} == 1){
				$rc++;
				push @tmp, $n;
			}
		}
		print "Interspersed Nodes ($rc nodes):\n";
		print join("\t", @tmp)."\n";
	}
}

sub ccc{
	my ($pe, $kN, $cN) = @_;

	if($cN<$kN){return 'NA';}
	if($cN==$kN){return 1;}
	
	if ($cN>45) {
		$cN=45;
	}
	my $pvalue = $pe**($kN*($kN-1)/2);
	my $edgecount = $cN*($cN-1)/2;
	my $result = 0;
	
	my $tmp1 = 0;
	my $tmp2 = 1;
	for(my $i=$edgecount; $i>=0; $i--){
		$tmp1 = ($pe**$i)*((1-$pe)**($edgecount-$i))*$tmp2;
		$pvalue -= $tmp1;
		if($pvalue<=0){
			if($pvalue==0){
				$result = $i; last;
			}else{
				$result = $i+1; last;
			}
		}else{
			$tmp2 *= ($i/($edgecount-$i+1));
		}
	}

	return ($result/$edgecount);
}
