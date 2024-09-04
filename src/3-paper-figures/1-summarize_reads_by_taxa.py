import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy.stats import pearsonr, spearmanr


def data_wrangling(samples):
    summary_file = f'data/pipeline_mock/mock_read_count_report.csv'  # Assuming summary file contains total reads
    summary_df = pd.read_csv(summary_file)
    # Initialize an empty list to hold dataframes
    all_data = []

    for sample in samples:
        # sample = samples[0]
        # Define file paths
        composition_file = f'data/pipeline_mock/composition/{sample}.tsv'
        metadata_file = f'data/pipeline_mock/metadata/{sample}.csv'
        bracken_output_file = f'data/pipeline_mock/reports/{sample}_4-bracken_czid_results_species_abundance.csv'

        # Load data into dataframes
        composition_df = pd.read_csv(composition_file, delimiter='\t', header=None, names=['accession_id', 'abundance_percentage'])
        metadata_df = pd.read_csv(metadata_file)
        bracken_df = pd.read_csv(bracken_output_file)

        # Get the total number of reads from the summary file
        total_reads = summary_df.loc[summary_df['sample_name'] == sample, 'raw_sample'].values[0]

        # Add sample name to each dataframe
        composition_df['sample_name'] = sample
        metadata_df['sample_name'] = sample
        bracken_df['sample_name'] = sample

        # Merge composition and metadata to get full taxonomic information
        composition_metadata_df = composition_df.merge(metadata_df, on=['accession_id', 'sample_name'])
        # Rename columns
        composition_metadata_df.rename(columns={'species_taxid': 'tax_id'}, inplace=True)
        composition_metadata_df.rename(columns={'species': 'taxa_name'}, inplace=True)
        # Compute the actual number of reads from the abundance percentage
        composition_metadata_df['true_reads'] = (composition_df['abundance_percentage'] * total_reads)
        # Round predicted reads to the nearest integer
        composition_metadata_df['true_reads'] = composition_metadata_df['true_reads']

        # Summarize reads from composition file (true reads)
        true_reads_summary = composition_metadata_df.groupby(['sample_name', 'taxa_name', 'tax_id'])['true_reads'].sum().reset_index()

        # Summarize reads from Bracken output (predicted reads)
        bracken_summary = bracken_df.groupby(['sample_name', 'tax_id'])['bracken_classified_reads'].sum().reset_index()
        bracken_summary.rename(columns={'bracken_classified_reads': 'predicted_reads'}, inplace=True)

        # Merge true reads summary with Bracken summary
        sample_summary_df = true_reads_summary.merge(bracken_summary, on=['sample_name', 'tax_id'], how='outer')
        sample_summary_df.fillna(0, inplace=True)

        # Round predicted reads to the nearest integer
        sample_summary_df['predicted_reads'] = sample_summary_df['predicted_reads'].round().astype(int)
        # Round predicted reads to the nearest integer
        sample_summary_df['true_reads'] = sample_summary_df['true_reads'].round().astype(int)
        # Round predicted reads to the nearest integer
        sample_summary_df['tax_id'] = sample_summary_df['tax_id'].astype(int)

        # Keep only rows where true reads is more than 0
        sample_summary_df = sample_summary_df[sample_summary_df['true_reads'] > 0]        
        # Keep only rows where predicted reads is more than 0
        sample_summary_df = sample_summary_df[sample_summary_df['predicted_reads'] > 0]        
        # Remove the human reads from the summary
        sample_summary_df = sample_summary_df[sample_summary_df['tax_id'] != 9606]

        # Append to the list of dataframes
        all_data.append(sample_summary_df)

    # Combine all sample data into a single dataframe
    combined_df = pd.concat(all_data, ignore_index=True)
    # Save the summary to a CSV file
    combined_df.to_csv('results/summary_reads.csv', index=False)
    print("Summary of reads has been saved to 'summary_reads.csv'")
    return combined_df


def statistics_analysis(combined_df):
    # Compute correlation
    pearson_corr, _ = pearsonr(combined_df['true_reads'], combined_df['predicted_reads'])
    spearman_corr, _ = spearmanr(combined_df['true_reads'], combined_df['predicted_reads'])

    print(f"Pearson Correlation: {pearson_corr}")
    print(f"Spearman Correlation: {spearman_corr}")

    # Calculate MAE and RMSE
    mae = np.mean(np.abs(combined_df['true_reads'] - combined_df['predicted_reads']))
    rmse = np.sqrt(np.mean((combined_df['true_reads'] - combined_df['predicted_reads'])**2))

    print(f"Mean Absolute Error (MAE): {mae}")
    print(f"Root Mean Squared Error (RMSE): {rmse}")

    # Create Bland-Altman Plot
    mean_reads = np.mean([combined_df['true_reads'], combined_df['predicted_reads']], axis=0)
    diff_reads = combined_df['true_reads'] - combined_df['predicted_reads']

    plt.figure(figsize=(10, 6))
    plt.scatter(mean_reads, diff_reads, alpha=0.5)
    plt.axhline(np.mean(diff_reads), color='red', linestyle='--')
    plt.axhline(np.mean(diff_reads) + 1.96*np.std(diff_reads), color='blue', linestyle='--')
    plt.axhline(np.mean(diff_reads) - 1.96*np.std(diff_reads), color='blue', linestyle='--')
    plt.xlabel('Mean of True and Predicted Reads')
    plt.ylabel('Difference between True and Predicted Reads')
    plt.title('Bland-Altman Plot')
    plt.show()


def taxon_barplot(samples, combined_df):
    # Turning copy on write to allow for changes in the slices of a dataframe
    pd.options.mode.copy_on_write = True
    # Define a color blind-friendly palette
    color_blind_palette = sns.color_palette(palette="colorblind", n_colors=2)

    # Filter data for a specific sample and create side-by-side bar chart
    for sample in samples:
        sample_data = combined_df[combined_df['sample_name'] == sample].copy()
        # Order taxa by the highest to lowest true read number
        ordered_taxa = sample_data.groupby('taxa_name')['true_reads'].sum().sort_values(ascending=False).index
        sample_data['taxa_name'] = pd.Categorical(sample_data['taxa_name'], categories=ordered_taxa, ordered=True)
        sample_data = sample_data.sort_values('taxa_name')
        
        # Get the total number of unique taxa
        num_taxa = sample_data['taxa_name'].nunique()
        
        # Split taxa into chunks of 50
        taxa_chunks = [ordered_taxa[i:i + 50] for i in range(0, num_taxa, 50)]
        
        # Generate separate plots for each chunk
        for chunk_idx, chunk in enumerate(taxa_chunks):
            chunk_data = sample_data[sample_data['taxa_name'].isin(chunk)].copy()
            
            # Ensure chunk_data does not contain any missing or zero values
            chunk_data = chunk_data[(chunk_data['true_reads'] > 0) | (chunk_data['predicted_reads'] > 0)]
            
            if chunk_data.empty:
                continue  # Skip empty chunks

            # Create a new DataFrame for the chunk
            chunk_df = pd.DataFrame({
                'taxa_name': chunk_data['taxa_name'],
                'tax_id': chunk_data['tax_id'],
                'true_reads': chunk_data['true_reads'],
                'predicted_reads': chunk_data['predicted_reads'],
                'sample': chunk_data['sample_name']
            })

            # Melt the chunk data for plotting
            chunk_data_melted = pd.melt(chunk_df, id_vars=['taxa_name', 'tax_id'], value_vars=['true_reads', 'predicted_reads'],
                                        var_name='Read Type', value_name='Reads')

            # Dynamically adjust figure width: base width + additional width per taxon
            base_width = 10
            additional_width_per_taxon = 0.5
            fig_width = base_width + additional_width_per_taxon * len(chunk_df['taxa_name'].unique())

            plt.figure(figsize=(fig_width, 8))  # Adjust figure size dynamically
            ax = sns.barplot(x='taxa_name', y='Reads', hue='Read Type', data=chunk_data_melted, palette=color_blind_palette)
            plt.xticks(rotation=45, ha='right', fontsize=12)  # Rotate x-axis labels and increase font size
            plt.xlabel('Taxa', fontsize=14)
            plt.ylabel('Number of Reads', fontsize=14)
            plt.title(f'Comparison of True and Predicted Reads for {sample} (Part {chunk_idx + 1}/{len(taxa_chunks)})', fontsize=16)
            plt.legend(title='Read Type', fontsize=12, title_fontsize=14)

            # Adjust x-axis label spacing
            plt.tight_layout()

            # Save the figure 
            if len(taxa_chunks) > 1:
                # Save with higher resolution
                plt.savefig(f'results/{sample}_reads_comparison_part_{chunk_idx + 1}.png', dpi=300)
            else:            
                # Save with higher resolution
                plt.savefig(f'results/{sample}_reads_comparison.png', dpi=300) 
            plt.close()


def main():
    # List of sample names
    # samples = ['CSI004', 'SI003', 'SI007', 'SI035', 'SI041_1', 'throat_with_pathogen_01', 'throat_with_pathogen_02', 'throat_with_pathogen_03', 'throat_with_pathogen_04']  # Add all your sample names here
    samples = ['SI035']

    combined_df = data_wrangling(samples)

    taxon_barplot(samples, combined_df)

    
if __name__ == '__main__':
    main()
