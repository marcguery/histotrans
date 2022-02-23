#!/bin/bash
DIR=test/vcf
mkdir -p $DIR
cd $DIR

vcfs=( "pf_DELLYv0-8-7.vcf" )

for vcf in ${vcfs[@]};do
	samples=( $(grep -m 1 "#CHROM" "$vcf" | cut -f 10-) )
	filename=$(basename $vcf)
	filename="${filename%.*}"

	column=10
	fileout=file.out
	echo "" > $fileout
	for sample in ${samples[@]};do
		##For a sample to be included in the CSV file:
			#'($9+$10+$11+$12) < 1': at least one read
			#'($10+$12)/($9+$10+$11+$12) < 0.5': variant allele frequency of 0.5 at least
			#'$4 == "LowQual"': Must not be LowQual (must be PASS)
		##Sample is not included if any of the tests above fails
		paste --delimiters=',' <(cat $fileout) \
		<(grep -v "#" "$vcf" | cut -f $column | \
			awk -F':' -v sample=$sample -v OFS=',' '{ if (($9+$10+$11+$12) < 1 || ($10+$12)/($9+$10+$11+$12) < 0.5 || $4 == "LowQual")
						print "NA";
					else
						print sample;}') > $fileout.tmp
		mv $fileout.tmp $fileout
		((column++))
	done

	paste --delimiters="," <(grep -v "#" "$vcf" | cut -f 1,2,3,4,5 --output-delimiter=",") \
	<(grep -v "#" "$vcf" | cut -f 8 | cut -f 4-6 -d";" --output-delimiter="," | sed -r 's/((END=[0-9]+,CHR2)|CHR2|END|POS2)=//g' | cut -f1,2 -d",") \
	<(cut -d"," -f2- $fileout) > "$filename"-table.csv

	sed -i 's/,NA//g' "$filename"-table.csv
	sed -i 's/,,/,/g' "$filename"-table.csv

	cp "$filename"-table.csv "$filename"-table.csv.tmp

	awk -F',' '$8!="" { print $0 }' "$filename"-table.csv.tmp \
	| sort -t ',' -k1,1 -k2,2n \
	> "$filename"-table.csv

	paste -d"," <(cut -d"," -f1-7 "$filename"-table.csv) <(cut -f8- -d"," --output-delimiter=":" "$filename"-table.csv) \
	> "$filename"-table.csv.tmp

	mv "$filename"-table.csv.tmp "$filename"-table-full.csv
	paste -d "," <(grep -E ",TRA|,BND" "$filename"-table-full.csv | cut -d"," -f3) \
		<(grep -E ",TRA|,BND" "$filename"-table-full.csv  | cut -d"," -f1,2,6-) > "$filename"-table.csv
done

/bin/rm $fileout

cd -
