# Histology Feature Extraction Pipeline

A Nextflow pipeline for extracting features from histology whole slide images (WSI) using multiple patch and slide encoders via [TRIDENT](https://github.com/mahmoodlab/TRIDENT).

## Overview

This pipeline performs the following steps:

1. **Segmentation**: Tissue segmentation of whole slide images
2. **Coordinate Extraction**: Extraction of patch coordinates based on configuration parameters
3. **Patch Feature Extraction**: Extraction of patch-level features using various patch encoders
4. **Slide Feature Extraction**: Aggregation of patch features to slide-level representations using slide encoders

The pipeline is optimized to avoid redundant computation by:
- Running segmentation and coordinate extraction only once per unique configuration of `(patch_size, mag, batch_size, overlap)`
- Reusing these results for all encoder combinations that share the same configuration

## Requirements

- Nextflow (>= 25.04.7)
- Python 3.10+ (for PRISM encoder support)
- TRIDENT repository cloned and configured
- CHIEF repository (if using CHIEF slide encoder)
- Access to required model weights and checkpoints

## Installation

1. Clone this repository:
```bash
git clone https://github.com/digenoma-lab/HistologyFeatureExtraction.git
cd HistologyFeatureExtraction
```

2. Install Python dependencies:
```bash
pip install -r requirements.txt
```

3. Set up TRIDENT:
   - Clone the TRIDENT repository
   - Configure model paths in `trident/slide_encoder_models/local_ckpts.json`
   - See [TRIDENT documentation](https://github.com/mahmoodlab/TRIDENT) for details

4. Set up CHIEF (if using CHIEF encoder):
   - Clone the CHIEF repository
   - Download required weights
   - Update `params/params.yml` with the CHIEF directory path

## Configuration

### Parameters File

Edit `params/params.yml` to configure:

- `dataset`: Path to CSV file with list of WSIs to process
- `feature_extractors`: Path to CSV file with encoder configurations
- `wsi_dir`: Directory containing WSI files
- `outdir`: Output directory for results
- `trident_dir`: Path to TRIDENT repository
- `chief_dir`: Path to CHIEF repository (if using)

### Feature Extractors Configuration

The `params/feature_extractors.csv` file defines which encoders to use. Format:

```csv
patch_encoder,slide_encoder,patch_size,mag,batch_size,overlap
uni_v1,mean-uni_v1,256,20,200,0
ctranspath,chief,256,20,200,0
```

### Dataset Configuration

The `params/custom_wsis.csv` file lists WSIs to process. Format:

```csv
case_id,wsi
TCGA-3C-AAAU,TCGA-3C-AAAU-01A-01-TS1.2F52DD63-7476-4E85-B7C6-E06092DB6CC1.svs
```

## Usage

### Basic Usage

```bash
nextflow run main.nf -profile kutral -params-file params/params.yml
```

### Profiles

- `kutral`: For SLURM cluster execution (ngen-ko queue)
- `local`: For local execution

### Output

Results are organized in the output directory:

- `results/segmentation/`: Segmentation results (contours, thumbnails)
- `results/coordinates/`: Extracted patch coordinates
- `results/patch_features/`: Patch-level feature files
- `results/slide_features/`: Slide-level feature files and all intermediate outputs

## Supported Encoders

### Patch Encoders
- uni_v1, uni_v2
- phikon_v2
- resnet50
- virchow, virchow2
- conch_v15
- ctranspath

### Slide Encoders
- mean-* (mean pooling over patch features)
- titan
- chief
- prism

See TRIDENT documentation for full list and requirements.

## Pipeline Structure

```
main.nf
├── segmentation (runs once per dataset)
├── preprocessing
│   ├── extract_coordinates (runs once per unique config)
└── feature_extraction
    ├── patch_features (runs for each encoder combination)
    └── slide_features (runs for each encoder combination)
```

## Citation

If you use this pipeline, please cite:

- TRIDENT: [Citation information]
- CHIEF: [Citation information if used]

## License

See LICENSE file for details.

## Author

Gabriel Cabas - DiGenoma Lab
