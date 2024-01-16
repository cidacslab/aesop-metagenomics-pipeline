# AESOP-Metagenomics pipeline

The following document describes the process used for taxonomic annotation of metagenome sample pools. 

This proccess starts downloading fastq files from basespace. From that, we performed adapter removal, quality filter and trimming with fastp. Then, we removed dna contamination from sequences using bowtie, using a pre-created common host contaminant index, with genomes from host models, as mouse, cow and human. And finally we used Kraken2 to annotate each read.

## 1) Samples QC

### 1.1) [FASTP (v0.23.2)](https://github.com/OpenGene/fastp): adapter removal and quality control.

Using FASTP to remove sequence adapters from samples.

* Input: raw .fastq files downloaded from Illumina Basespace
* Output: quality filtered without adapters fastq files.

Parameters:

* --length_required: reads shorter than 50 bp will be discarded
* --average_qual: if one read's average quality score < 20, then this read/pair is discarded
* --cut_front: move a sliding window from front (5') to tail, drop the bases in the window if its mean quality < threshold, stop otherwise.
* --cut_front_window_size: the window size option of cut_front = 1
* --cut_front_mean_quality: the mean quality requirement option for cut_front = 20
* --cut_tail:  move a sliding window from tail (3') to front, drop the bases in the window if its mean quality < threshold, stop otherwise.
* --cut_tail_window_size: the window size option of cut_tail = 1
* --cut_tail_mean_quality: the mean quality requirement option for cut_tail = 20
* --n_base_limit: if one read's number of N base is >n_base_limit, then this read/pair is discarded. = 2

Command line:
```bash
  fastp -i sample_id_1.fastq -I sample_id_2.fastq
  -o sample_id_1_filt_and_trim.fastq -O sample_id_2_filt_and_trim.fastq
  -merge --merged_out sample_id_merged.fastq
  --length_required 50
  --average_qual 20
  --cut_front --cut_front_window_size 1 --cut_front_mean_quality 20
  --cut_tail --cut_tail_window_size 1 --cut_tail_mean_quality 20
  --n_base_limit 2
```

Sources:
* Minimum quality score value: [1](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0205575), [2](https://www.nature.com/articles/s41598-020-57464-2), [3](https://www.nature.com/articles/s41598-021-88318-0)
* Left and right trim positions: [4](https://www.nature.com/articles/s41396-021-01103-9), [5](https://www.nature.com/articles/s41467-020-20422-7)


### 1.2) [Bowtie2](https://github.com/BenLangmead/bowtie2): removal of Host associated DNA

* Inputs: quality filtered .fastq files
* Outputs: fasta file without host sequences

First, download genomes that we want to remove. The reference genomes can be found [here](https://docs.google.com/spreadsheets/d/15wnnGk5jHeaSDbm7RFrzBNPADKqS1bUhCPO5eKs7W6o/edit?usp=sharing). Once downloaded the reference genome, generate a Bowtie2 index database:

```bash
bowtie2-build host_genome_sequence.fasta host_bowtie2_database
```

Then map the sample against the sequence database:

```bash
bowtie2 -x host_bowtie2_database -U mgm4739182.fasta -S mgm4739182_mapped_and_unmapped.sam
```

Parameters:

* x: The basename of the index for the reference genome.
* U: Reads (files with unpaired reads)
* S: File to write SAM alignments to

Convert “.sam” file to “.bam”:

```bash
samtools view -bS mgm4739182_mapped_and_unmapped.sam > mgm4739182_mapped_and_unmapped.bam
```

Parameters:

* S: input is in SAM format
* b: Output in the BAM format.

With samtools extract unmapped reads:

```bash
samtools fasta -f 4 mgm4739182_without_host_dna.fasta mgm4739182_mapped_and_unmapped.bam
```

Parameters:

* f: Only output alignments with all bits set in INT present in the FLAG field

Sources: [1](https://www.frontiersin.org/articles/10.3389/fmicb.2019.01277/full), [2](https://www.nature.com/articles/s41596-021-00508-2), [3](https://link.springer.com/article/10.1186/s40168-018-0426-3)

## 2) [Kraken 2](https://github.com/DerrickWood/kraken2): taxonomic sequence classifier that assigns taxonomic labels to DNA sequences.

* Inputs: short reads fasta files
* Outputs: Report files, output files, classified and unclassified sequences

Parameters:

* --minimum-hit-groups: Minimum number of hit groups (overlapping k-mers sharing the same minimizer) needed to make a call (default: 2)
* --confidence: Confidence score threshold (default: 0.0)

```bash
kraken2 --db $path_to_db $output --classified-out $output_kraken_class \
  --unclassified-out $output_kraken_unclass -output $output_kraken_output \
  --report $output_kraken_report --threads $nthreads_chosen
```
