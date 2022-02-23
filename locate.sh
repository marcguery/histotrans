#!/bin/bash

SAMTOOLS=samtools
TRANSTABLE=test/vcf/pf-table.csv 	#Headerless CSV file with these fields: id,chr1,pos1,chr2,pos2,sample file name
									#e.g.: TRA00000001,Pf3D7_14_v3,905611,Pf3D7_10_v3,1057707,file1.bam:file2.bam:file3.bam
READDIR=test/bams	#BAM directory
GENOME=test/genome/PlasmoDB-46_Pfalciparum3D7_Genome.fasta	#Genome fasta file
OUTDIR=out	#Output directory
rasterize=src/rasterize.js

echo "" > log.txt
echo "" > err.txt

cat $TRANSTABLE | while read line; do
	id=$(cut -d"," -f 1 <(echo $line))	#e.g. TRA00000001
	chr1=$(cut -d"," -f 2 <(echo $line))	#e.g. Pf3D7_14_v3
	pos1=$(cut -d"," -f 3 <(echo $line))	#e.g. 905611
	chr2=$(cut -d"," -f 4 <(echo $line))	#e.g. Pf3D7_10_v3
	pos2=$(cut -d"," -f 5 <(echo $line))	#e.g. 1057707
	t1="$chr1:$(($pos1-150))-$(($pos1+150))"	#e.g.: Pf3D7_14_v3:905461-905761
	t2="$chr2:$(($pos2-150))-$(($pos2+150))" 	#e.g.: Pf3D7_10_v3:1057557-1057857
	mkdir -p $OUTDIR/reads/$id	#Files for all reads
	mkdir -p $OUTDIR/transreads/$id	#Files for translocation reads

	samples=( $(cut -d"," -f 6 <(echo $line) \
		| cut -f 1- -d ":" --output-delimiter=$'\t') )	#e.g.: ( file1.bam file2.bam file3.bam )

	echo "Processing translocation reads between $t1 and $t2 in ${#samples[@]} samples"

	for ((i=0;i<${#samples[@]};i++));do
		$SAMTOOLS view -H -O SAM $READDIR/${samples[$i]} "$t1" > $OUTDIR/reads/$id/reads.1.samheader
		$SAMTOOLS view -H -O SAM $READDIR/${samples[$i]} "$t2" > $OUTDIR/reads/$id/reads.2.samheader

		$SAMTOOLS view -O SAM $READDIR/${samples[$i]} "$t1" > $OUTDIR/reads/$id/reads.1.sam
		$SAMTOOLS view -O SAM $READDIR/${samples[$i]} "$t2" > $OUTDIR/reads/$id/reads.2.sam
		reads1num=$(cut -f1 $OUTDIR/reads/$id/reads.1.sam | sort | uniq | wc -l | cut -f1 -d " ")
		reads2num=$(cut -f1 $OUTDIR/reads/$id/reads.2.sam | sort | uniq | wc -l | cut -f1 -d " ")
		echo "$reads1num $reads2num"

		$SAMTOOLS view -O SAM $READDIR/${samples[$i]} "$t1" > $OUTDIR/reads/$id/${samples[$i]}-$chr1-$pos1.sam
		$SAMTOOLS view -O SAM $READDIR/${samples[$i]} "$t2" > $OUTDIR/reads/$id/${samples[$i]}-$chr2-$pos2.sam
		linenumber1=$(wc -l $OUTDIR/reads/$id/${samples[$i]}-$chr1-$pos1.sam | cut -f1 -d " ")
		[ $linenumber1 -gt 0 ] && 
			pageheight1=$(bc -l <<< "150+150*l($linenumber1)") || 
			pageheight1=150
		linenumber2=$(wc -l $OUTDIR/reads/$id/${samples[$i]}-$chr2-$pos2.sam | cut -f1 -d " ")
		[ $linenumber2 -gt 0 ] && 
			pageheight2=$(bc -l <<< "150+150*l($linenumber2)") || 
			pageheight2=150
		COLUMNS=300 $SAMTOOLS tview -d H $READDIR/${samples[$i]} -p "$t1" --reference $GENOME > $OUTDIR/reads/$id/${samples[$i]}-$chr1-$pos1.html
		COLUMNS=300 $SAMTOOLS tview -d H $READDIR/${samples[$i]} -p "$t2" --reference $GENOME > $OUTDIR/reads/$id/${samples[$i]}-$chr2-$pos2.html
		google-chrome --headless --disable-gpu --screenshot=$OUTDIR/reads/$id/${samples[$i]}-$chr1-$pos1.png $OUTDIR/reads/$id/${samples[$i]}-$chr1-$pos1.html --window-size=2500,$pageheight1 1>>log.txt 2>>err.txt
		google-chrome --headless --disable-gpu --screenshot=$OUTDIR/reads/$id/${samples[$i]}-$chr2-$pos2.png $OUTDIR/reads/$id/${samples[$i]}-$chr2-$pos2.html --window-size=2500,$pageheight2 1>>log.txt 2>>err.txt
		
		grep -f <(cut -f1 $OUTDIR/reads/$id/reads.2.sam) $OUTDIR/reads/$id/reads.1.sam > $OUTDIR/transreads/$id/transreads.1.sam
		grep -f <(cut -f1 $OUTDIR/transreads/$id/transreads.1.sam) $OUTDIR/reads/$id/reads.2.sam > $OUTDIR/transreads/$id/transreads.2.sam

		transreads1num=$(cut -f1 $OUTDIR/transreads/$id/transreads.1.sam | sort | uniq | wc -l | cut -f1 -d " ")
		transreads2num=$(cut -f1 $OUTDIR/transreads/$id/transreads.2.sam | sort | uniq | wc -l | cut -f1 -d " ")
		echo "$transreads1num $transreads2num"

		$SAMTOOLS view -O BAM <(cat $OUTDIR/reads/$id/reads.1.samheader $OUTDIR/transreads/$id/transreads.1.sam) | $SAMTOOLS sort - > $OUTDIR/transreads/$id/transreads.1.bam
		$SAMTOOLS view -O BAM <(cat $OUTDIR/reads/$id/reads.2.samheader $OUTDIR/transreads/$id/transreads.2.sam) | $SAMTOOLS sort - > $OUTDIR/transreads/$id/transreads.2.bam

		$SAMTOOLS index $OUTDIR/transreads/$id/transreads.1.bam
		$SAMTOOLS index $OUTDIR/transreads/$id/transreads.2.bam

		$SAMTOOLS view -O SAM $OUTDIR/transreads/$id/transreads.1.bam "$t1" > $OUTDIR/transreads/$id/${samples[$i]}-$chr1-$pos1.sam
		$SAMTOOLS view -O SAM $OUTDIR/transreads/$id/transreads.2.bam "$t2" > $OUTDIR/transreads/$id/${samples[$i]}-$chr2-$pos2.sam
		linenumber1=$(wc -l $OUTDIR/transreads/$id/${samples[$i]}-$chr1-$pos1.sam | cut -f1 -d " ")
		[ $linenumber1 -gt 0 ] && 
			pageheight1=$(bc -l <<< "150+150*l($linenumber1)") || 
			pageheight1=150
		linenumber2=$(wc -l $OUTDIR/transreads/$id/${samples[$i]}-$chr2-$pos2.sam | cut -f1 -d " ")
		[ $linenumber2 -gt 0 ] && 
			pageheight2=$(bc -l <<< "150+150*l($linenumber2)") || 
			pageheight2=150
		COLUMNS=300 $SAMTOOLS tview -d H $OUTDIR/transreads/$id/transreads.1.bam -p "$t1" --reference $GENOME > $OUTDIR/transreads/$id/${samples[$i]}-$chr1-$pos1.html
		COLUMNS=300 $SAMTOOLS tview -d H $OUTDIR/transreads/$id/transreads.2.bam -p "$t2" --reference $GENOME > $OUTDIR/transreads/$id/${samples[$i]}-$chr2-$pos2.html
		google-chrome --headless --disable-gpu --screenshot=$OUTDIR/transreads/$id/${samples[$i]}-$chr1-$pos1.png $OUTDIR/transreads/$id/${samples[$i]}-$chr1-$pos1.html --window-size=2500,$pageheight1 1>>log.txt 2>>err.txt
		google-chrome --headless --disable-gpu --screenshot=$OUTDIR/transreads/$id/${samples[$i]}-$chr2-$pos2.png $OUTDIR/transreads/$id/${samples[$i]}-$chr2-$pos2.html --window-size=2500,$pageheight2 1>>log.txt 2>>err.txt
	done

done
