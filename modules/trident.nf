process segmentation {
    input:
    tuple path(wsi_dir), path(dataset), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap), path(trident_dir), path(chief_dir)
    output:
    tuple path(wsi_dir), path(dataset), path("processed_data/"), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap), path(trident_dir), path(chief_dir), emit: seg
    script:
    """
    python ${trident_dir}/run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir processed_data/${wsi_dir} --task seg \\
        --batch_size ${batch_size} --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p processed_data/${wsi_dir}/thumbnails/
    mkdir -p processed_data/${wsi_dir}/contours/
    mkdir -p processed_data/${wsi_dir}/contours_geojson/
    """
}

process extract_coordinates {
    input:
    tuple path(wsi_dir), path(dataset), path(job_dir), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap), path(trident_dir), path(chief_dir)
    output:
    tuple path(wsi_dir), path(dataset), path(job_dir), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap), path(trident_dir), path(chief_dir), emit: coords
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
    tuple path(wsi_dir), path(dataset), path(job_dir), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap), path(trident_dir), path(chief_dir)
    output:
    tuple path(wsi_dir), path(dataset), path(job_dir), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap), path(trident_dir), path(chief_dir), emit: patch_features
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
    tuple path(wsi_dir), path(dataset), path(job_dir), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap), path(trident_dir), path(chief_dir)
    output:
    path("${job_dir}/${wsi_dir}/${mag}x_${patch_size}px_${overlap}px_overlap/slide_features_${slide_encoder}/"), emit: slide_features
    path("${job_dir}/${wsi_dir}/${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/"), emit: patch_features
    path("${job_dir}/${wsi_dir}/${mag}x_${patch_size}px_${overlap}px_overlap/patches/"), emit: patches
    path("${job_dir}/${wsi_dir}/${mag}x_${patch_size}px_${overlap}px_overlap/visualization/"), emit: visualization
    path("${job_dir}/${wsi_dir}/contours"), emit: contours
    path("${job_dir}/${wsi_dir}/contours_geojson"), emit: contours_geojson
    path("${job_dir}/${wsi_dir}/thumbnails"), emit: thumbnails

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