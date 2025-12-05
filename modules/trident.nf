process segmentation {
    publishDir "${params.outdir}/", mode: "copy"
    input:
    path(dataset)
    path(wsi_dir)
    path(trident_dir)
    output:
    path("processed_data/"), emit: seg
    script:
    """
    python ${trident_dir}/run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir processed_data/${wsi_dir} --task seg \\
        --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p processed_data/${wsi_dir}/thumbnails/
    mkdir -p processed_data/${wsi_dir}/contours/
    mkdir -p processed_data/${wsi_dir}/contours_geojson/
    """
}

process extract_coordinates {
    publishDir "$params.outdir/", mode: "copy"
    input:
    tuple path(job_dir), val(patch_size), val(mag), val(batch_size), val(overlap)
    path(dataset)
    path(wsi_dir)
    path(trident_dir)
    output:
    tuple path(job_dir), val(patch_size), val(mag), val(batch_size), val(overlap), emit: coords
    script:
    """
    python ${trident_dir}/run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir ${job_dir}/${wsi_dir} --patch_size ${patch_size} --mag ${mag} \\
        --task coords --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p ${job_dir}/${wsi_dir}/${mag}x_${patch_size}px_${overlap}px_overlap/patches/
    mkdir -p ${job_dir}/${wsi_dir}/${mag}x_${patch_size}px_${overlap}px_overlap/visualization/
    """
}

process patch_features {
    input:
    tuple path(job_dir), val(patch_encoder), val(patch_size), val(mag), val(batch_size), val(overlap)
    path(dataset)
    path(wsi_dir)
    path(trident_dir)
    output:
    tuple path(job_dir), val(patch_encoder), val(patch_size), val(mag), val(batch_size), val(overlap), emit: patch_features
    script:
    """
    python ${trident_dir}/run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir ${job_dir}/${wsi_dir} --patch_size ${patch_size} \\
        --mag ${mag} --task feat --patch_encoder ${patch_encoder} \\
        --batch_size ${batch_size} --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p ${job_dir}/${wsi_dir}/${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/
    """
}

process slide_features {
    publishDir "${params.outdir}", mode: 'copy'
    input:
    tuple path(job_dir), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap)
    path(dataset)
    path(wsi_dir)
    path(trident_dir)
    output:
    path("${job_dir}/${wsi_dir}/${mag}x_${patch_size}px_${overlap}px_overlap/slide_features_${slide_encoder}/"), emit: slide_features
    path("${job_dir}/${wsi_dir}/${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/"), emit: patch_features
    path("${job_dir}/${wsi_dir}/${mag}x_${patch_size}px_${overlap}px_overlap/patches/"), emit: patches
    path("${job_dir}/${wsi_dir}/${mag}x_${patch_size}px_${overlap}px_overlap/visualization/"), emit: visualization
    script:
    """
    python ${trident_dir}/run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir ${job_dir}/${wsi_dir} --patch_size ${patch_size} \\
        --mag ${mag} --task feat --slide_encoder ${slide_encoder} \\
        --batch_size ${batch_size} --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p ${job_dir}/${wsi_dir}/${mag}x_${patch_size}px_${overlap}px_overlap/slide_features_${slide_encoder}/
    """
}