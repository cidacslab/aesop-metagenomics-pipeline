# Creating and Plotting Results


## Installation

Install the necessary software using the following commands:

```bash
# Install R and its dependencies
sudo apt update
sudo apt install python3 python3-pip make
pip3 install biopython

```

## Usage

To plot the results, like presented in the paper, after running the pipeline place the bracken outputs in folder /data/pipeline_mock/reports and execute the following command:

```bash
Rscript src/rscript_paper_plots/main.r
```
