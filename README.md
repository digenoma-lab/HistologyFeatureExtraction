# Histology Feature Extraction Pipeline

<p align="center">
  <img src="imgs/logo.png" alt="Histology Feature Extraction Pipeline" width="40%"/>
</p>

A Nextflow pipeline for extracting features from histology whole slide images (WSI) using multiple patch and slide encoders via [TRIDENT](https://github.com/mahmoodlab/TRIDENT).

## Overview

The pipeline runs four stages in order, delegating each stage to TRIDENT's `run_batch_of_slides.py`:

1. **Segmentation** (`segmentation_batch`): tissue segmentation of whole slide images
2. **Coordinate extraction** (`extract_coordinates_batch`): patch coordinates per `(mag, patch_size, overlap)` configuration
3. **Patch feature extraction** (`patch_features_batch`): patch-level features per patch encoder
4. **Slide feature extraction** (`slide_features_batch`): slide-level features per slide encoder

Before each stage, an **intersect** step compares expected outputs against files already present in `outdir`. Only missing work is batched and submitted. Re-running the pipeline is incremental: completed files are skipped automatically.

### Batch execution

Work is grouped into batches rather than processed slide-by-slide:

- **Segmentation**: one batch with all slides missing a contour
- **Coordinates**: one batch per unique `(mag, patch_size, overlap)` with pending patches
- **Patch features**: one batch per unique `(patch_encoder, mag, patch_size, overlap)` with pending `.h5` files
- **Slide features**: one batch per unique `(slide_encoder, mag, patch_size, overlap)` with pending `.h5` files

Each batch receives a `dataset.csv` (`case_id,wsi`) passed to TRIDENT via `--custom_list_of_wsis`, so only pending slides are processed.

Stages are chained sequentially: coordinates wait for segmentation, patch features wait for coordinates, and slide features wait for patch features.

### Efficiency

- Segmentation and coordinate extraction run once per unique `(mag, patch_size, overlap)` configuration, shared across all encoder pairs that use the same settings
- Patch and slide feature extraction run only for encoder combinations with missing outputs
- If `outdir` does not exist or is empty, all outputs are treated as pending and the pipeline starts from scratch

## Requirements

- Nextflow (>= 25.04.7)
- Python 3.10+ (for PRISM encoder support)
- TRIDENT repository cloned and configured
- CHIEF repository (if using CHIEF slide encoder)
- Access to required model weights and checkpoints
- Hugging Face account with access token (for downloading model weights)

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
   - Update `chief_dir` in `nextflow.config` or `params/params.yml`

## Configuration

### Parameters File

Edit `params/params.yml` to configure:

- `dataset`: Path to CSV file with list of WSIs to process
- `wsi_dir`: Directory containing WSI files
- `outdir`: Output directory for results (default: `results`)
- `trident_dir`: Path to TRIDENT repository (default in `nextflow.config`)
- `token`: Hugging Face access token for downloading model weights (pass via CLI, see Usage)

### Feature Extractors Configuration

Encoder combinations are defined in `params/feature_extractors.csv`:

```csv
patch_encoder,slide_encoder,patch_size,mag,batch_size,overlap
uni_v1,mean-uni_v1,256,20,200,0
ctranspath,chief,256,20,200,0
```

Each row defines one patch encoder / slide encoder pair and the patch extraction settings used for both.

### Dataset Configuration

The dataset CSV (e.g. `params/custom_wsis.csv`) lists WSIs to process:

```csv
case_id,wsi
TCGA-3C-AAAU,TCGA-3C-AAAU-01A-01-TS1.2F52DD63-7476-4E85-B7C6-E06092DB6CC1.svs
```

## Usage

### Basic Usage

```bash
nextflow run main.nf -profile kutral -params-file params/params.yml --token <HUGGINGFACE_TOKEN>
```

Resume a previous run (re-submit only pending or failed tasks):

```bash
nextflow run main.nf -profile kutral -params-file params/params.yml --token <HUGGINGFACE_TOKEN> -resume
```

> **Note**: The `--token` parameter is required. You can obtain a Hugging Face access token from [https://huggingface.co/settings/tokens](https://huggingface.co/settings/tokens). Make sure your token has access to the required model repositories.

### Profiles

- `kutral`: SLURM cluster execution (`ngen-ko` queue, Singularity enabled)
- `local`: Local execution with Singularity

### Output

Results are written under `outdir` using TRIDENT's layout:

```
results/
├── contours/                          # segmentation masks (.jpg)
├── contours_geojson/
├── thumbnails/
├── 20x_256px_0px_overlap/
│   ├── patches/                         # patch coordinates (.h5)
│   ├── visualization/
│   ├── features_<patch_encoder>/        # patch-level features (.h5)
│   └── slide_features_<slide_encoder>/  # slide-level features (.h5)
├── 20x_224px_0px_overlap/
│   └── ...
└── pipeline_info/                       # Nextflow reports (timeline, trace, DAG)
```

The intersect step checks for existing `.h5` and contour files to decide what still needs to run. Deleting specific output files and re-running with `-resume` will regenerate only those missing outputs.

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
├── intersect_all
│   ├── intersect (segmentation)  → dataset_segmentation
│   ├── intersect (patches)       → dataset_patches
│   ├── intersect (features)      → dataset_features
│   └── intersect (slide_features)→ dataset_slide_features
├── segmentation_batch            # pending slides → TRIDENT --task seg
├── extract_coordinates_batch     # per (mag, patch_size, overlap) → --task coords
├── patch_features_batch          # per patch_encoder batch → --task feat --patch_encoder
└── slide_features_batch          # per slide_encoder batch → --task feat --slide_encoder
```

Key modules:

| File | Role |
|------|------|
| `main.nf` | Main workflow: intersect + batch chain |
| `workflows/config.nf` | `intersect` workflow: detect pending work, build batch datasets |
| `modules/trident.nf` | Batch processes and TRIDENT integration |

## Citation

If you use this pipeline, please cite:

- [TRIDENT](https://github.com/mahmoodlab/TRIDENT)
- [CHIEF](https://github.com/hms-dbmi/CHIEF)

## License

See LICENSE file for details.

## Author

Gabriel Cabas - DiGenoma Lab
