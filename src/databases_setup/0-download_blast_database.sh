#!/bin/bash

# Download accessions2taxid files
wget ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/accession2taxid/prot.accession2taxid.FULL.gz*
wget ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/accession2taxid/nucl_gb.accession2taxid.gz*
wget ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/accession2taxid/nucl_wgs.accession2taxid.gz*
wget ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/accession2taxid/dead_nucl.accession2taxid.gz*

# Download taxonomy tax dump
wget ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.*
md5sum -c taxdump.tar.gz.md5
tar -xzvf taxdump.tar.gz

# Download nt_viruses blast db
parallel -j 10 "wget -c ftp://ftp.ncbi.nlm.nih.gov/blast/db/nt_viruses.{}.tar.gz" ::: {00..20}
parallel -j 10 "wget -c ftp://ftp.ncbi.nlm.nih.gov/blast/db/nt_viruses.{}.tar.gz.md5" ::: {00..20}
parallel -j 10 md5sum -c ::: nt_viruses.*.tar.gz.md5
parallel -j 10 tar -xzvf ::: nt_viruses.*.tar.gz
# for i in {00..22}; do tar -xzf nt_viruses.$i.tar.gz; done
blastdbcmd -db nt_viruses -entry all -outfmt "%a\t%T\t%S" | sed 's/\\t/\t/g' > nt_viruses_metadata.tsv

# Download nr blast db
parallel -j 20 "wget -c ftp://ftp.ncbi.nlm.nih.gov/blast/db/nr.{}.tar.gz" ::: {000..122}
parallel -j 20 "wget -c ftp://ftp.ncbi.nlm.nih.gov/blast/db/nr.{}.tar.gz.md5" ::: {000..122}
parallel -j 20 md5sum -c ::: nr.*.tar.gz.md5
parallel -j 20 tar -xzvf ::: nr.*.tar.gz

blastdbcmd -db nr -entry all -outfmt "%a\t%T\t%S" | sed 's/\\t/\t/g' > nr_metadata.tsv
nohup blastdbcmd -db nr -entry all -out nr.faa &> nr_to_fasta.log &
pigz -p 20 nr.faa

nohup diamond makedb --db nr --threads 50 --in nr.faa.gz \
--taxonmap /data/aesop/pipeline/databases/accession_taxid_mapping/prot.accession2taxid.FULL.gz \
--taxonnodes /data/aesop/pipeline/databases/taxdump/nodes.dmp \
--taxonnames /data/aesop/pipeline/databases/taxdump/names.dmp &> diamond_makedb.log &   
