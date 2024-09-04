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
# Install Fastp
conda install -c bioconda fastp

# Install Kraken2
conda install -c bioconda hisat2

# Install Kraken2
conda install -c bioconda bowtie2

# Install Kraken2
conda install -c bioconda kraken2

# Install Bracken
conda install -c bioconda bracken
```

## Usage

1. **Clone the repository**

```bash
git clone https://github.com/cidacslab/aesop-metagenomics-pipeline.git
cd aesop-metagenomics-pipeline
```

2. **Execute the pipeline**

Follow the steps detailed in our [METHODS](#methods)


## Citation

If you use this pipeline in your research, please cite the following paper:


> Viana, P. A. B.; Tschoeke, D. A.; de Moraes, L.; Santos, L. A.; Barral-Netto, M.; Khouri, R.; Ramos, P. I. P.; Meirelles, P. M.; (2024). Design and Implementation of a Metagenomic Analytical Pipeline for Respiratory Pathogen Detection.

* Corresponding Author: Pedro M Meirelles (pmeirelles@ufba.br)
* On any code issues, correspond to: Pablo Viana (pablo.alessandro@gmail.com)
