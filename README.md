[![DOI](https://zenodo.org/badge/852272699.svg)](https://doi.org/10.5281/zenodo.13983370)

# Design and Implementation of a Metagenomic Analytical Pipeline for Respiratory Pathogen Detection

## Abstract

**Objective**: We developed an in-house bioinformatics pipeline to improve the detection of respiratory pathogens in metagenomic sequencing data. This pipeline addresses the need for short-time analysis, high accuracy, scalability, and reproducibility in a high-performance computing environment.

**Results**: We evaluated our pipeline using ninety synthetic metagenomes designed to simulate nasopharyngeal swab samples. The pipeline successfully identified 177 out of 204 respiratory pathogens present in the compositions, with an average processing time of approximately 4 minutes per sample (processing 1 million paired-end reads of 150 base pairs). For the estimation of all the 470 taxa included in the compositions, the pipeline demonstrated high accuracy, identifying 420 and achieving a correlation of 0.9 between their actual and predicted relative abundances. Among the identified taxa, 27 were significantly underestimated or overestimated, including only three clinically relevant pathogens. These findings underscore the pipeline's effectiveness in pathogen detection and highlight its potential utility in respiratory pathogen surveillance.


## Methods

Our work performed the following steps:

1. [**Generation of Synthetic Metagenomes**]()
    1. Defining the samples composition
    2. Collecting the taxonomic ranks metadata
    3. Defining each taxon abundance
    4. Downloading the genomes of these taxa
    5. Generation of the synthetic metagenomes
2. [**Execution of Analysis Pipeline**]()
    1. Adapter Trimming and Quality Filtering
    2. Host Decontamination
    2. Taxa Annotation
    3. Species-Level taxa abundance retrieval
3. [**Creating and Plotting Results**]()


## Installation

Install the necessary software using the following commands:

```bash
# Python
sudo apt update
sudo apt install python3 python3-pip make
pip3 install biopython

# Install Fastp
sudo apt install fastp

# Install HISAT2
sudo apt install hisat2

# Install Bowtie2
sudo apt install bowtie2

# Install Samtools
sudo apt install samtools

# Install Kraken2
sudo apt install kraken2

# Install Bracken
wget https://github.com/jenniferlu717/Bracken/archive/refs/tags/v2.9.tar.gz
tar -xvzf v2.9.tar.gz
cd Bracken-2.9
./install_bracken.sh
sudo mv bracken /usr/local/bin/
sudo mv bracken-build /usr/local/bin/
sudo mv src/kmer2read_distr /usr/local/bin/
sudo mv src/est_abundance.py /usr/local/bin/
sudo mv src/generate_kmer_distribution.py /usr/local/bin/
```

## Usage

1. **Clone the repository**

```bash
git clone https://github.com/cidacslab/aesop-metagenomics-pipeline.git
cd aesop-metagenomics-pipeline
```

2. **Execute the pipeline**

To start the pipeline edit the parameters for the file locations, like explained in the [methods](#METHODS), and execute the following command:

```bash
./src/start_pipeline_job.sh

```

## Citation

If you use this pipeline in your research, please cite the following paper:


> Viana, P. A. B.; Tschoeke, D. A.; de Moraes, L.; Santos, L. A.; Barral-Netto, M.; Khouri, R.; Ramos, P. I. P.; Meirelles, P. M.; (2024). Design and Implementation of a Metagenomic Analytical Pipeline for Respiratory Pathogen Detection.

* Corresponding Author: Pedro M Meirelles (pmeirelles@ufba.br)
* On any code issues, correspond to: Pablo Viana (pablo.alessandro@gmail.com)
