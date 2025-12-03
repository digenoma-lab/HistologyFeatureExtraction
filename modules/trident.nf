process segmentation {
    input:
    tuple path(wsi_dir), path(dataset), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap)
    output:
    tuple path(wsi_dir), path(dataset), path("processed_data/"), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap), emit: seg
    script:
    """
    python run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir processed_data/tcga-brca --task seg \\
        --batch_size ${batch_size} --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p processed_data/tcga-brca/${mag}x_${patch_size}px_${overlap}px_overlap/
    """
}

process extract_coordinates {
    input:
    tuple path(wsi_dir), path(dataset), path(job_dir), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap)
    output:
    tuple path(wsi_dir), path(dataset), path(job_dir), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap), emit: coords
    script:
    """
    python run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir ${job_dir} --patch_size ${patch_size} --mag ${mag} \\
        --task coords --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p ${job_dir}/tcga-brca/${mag}x_${patch_size}px_${overlap}px_overlap/patches/
    mkdir -p ${job_dir}/tcga-brca/${mag}x_${patch_size}px_${overlap}px_overlap/visualization/
    """
}

process patch_features {
    input:
    tuple path(wsi_dir), path(dataset), path(job_dir), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap)
    output:
    tuple path(wsi_dir), path(dataset), path(job_dir), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap), emit: patch_features
    script:
    """
    python run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir ${job_dir} --patch_size ${patch_size} \\
        --mag ${mag} --task feat --patch_encoder ${patch_encoder} \\
        --batch_size ${batch_size} --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p ${job_dir}/tcga-brca/${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/
    """
}

process slide_features {
    publishDir "${params.outdir}", mode: 'copy'
    input:
    tuple path(wsi_dir), path(dataset), path(job_dir), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap)
    output:
    path("${job_dir}/tcga-brca/${mag}x_${patch_size}px_${overlap}px_overlap/slide_features_${slide_encoder}/"), emit: slide_features
    path("${job_dir}/tcga-brca/${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/"), emit: patch_features
    script:
    """
    python run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir ${job_dir} --patch_size ${patch_size} \\
        --mag ${mag} --task feat --slide_encoder ${slide_encoder} \\
        --batch_size ${batch_size} --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p ${job_dir}/tcga-brca/${mag}x_${patch_size}px_${overlap}px_overlap/slide_features_${slide_encoder}/
    """
}