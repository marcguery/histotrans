# histotrans

Generates pictures of aligned reads and translocation reads from a list of positions and bam files to load reads from.



# Usage

```bash
./locate.sh
```

# Input parameters

- ```TRANSTABLE:``` Location of the CSV file containing the list of positions and BAM files
- ```READDIR```: Location of the directory containing the BAM files
- ```GENOME```: Location of the genome FASTA file
- ```OUTDIR```: Location of the output directory

## Translocation CSV table

This CSV file should not contain any header and have these comma separated values for each translocation:

1. Unique identifier
2. Name of the chromosome 1
3. Position on the chromosome 1
4. Name of the chromosome 2
5. Position on the chromosome 2
6. Names of the samples to extract read each separated by *:* 

Notes: 

- Reads 150 base pairs before and after the provided positions will be extracted
- The names of the samples should match exactly the names of the BAM files including the *.bam* extension. Index files should be located in the same directory than their corresponding BAM file with the same name minus the *.bai* extension.

To produce such a file from a DELLY output use:

```bash
./make-table-from-vcf.sh
```

The script was tested with DELLY versions 0.7.5 and 0.8.7.



