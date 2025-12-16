process setup_dataset {
    input:
    tuple val(case_id), val(wsi)
    output:
    tuple val(case_id), val(wsi), path("dataset_${case_id}.txt"), emit: dataset
    script:
    """
    echo "case_id,wsi" > dataset_${case_id}.txt
    echo ${case_id},${wsi} >> dataset_${case_id}.txt
    """
    stub:
    """
    touch dataset_${case_id}.txt
    """
}
process segmentation {
    publishDir "${params.outdir}", mode: "copy", pattern: "thumbnails/*.jpg"
    publishDir "${params.outdir}", mode: "copy", pattern: "contours/*.jpg"
    publishDir "${params.outdir}", mode: "copy", pattern: "contours_geojson/*.geojson"
    input:
    tuple val(case_id), val(wsi), path(dataset)
    path(wsi_dir)
    path(trident_dir)
    output:
    tuple val(wsi), path(dataset), path("thumbnails/*.jpg"), path("contours/*.jpg"), path("contours_geojson/*.geojson"), emit: seg
    script:
    """
    python ${trident_dir}/run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir . --task seg \\
        --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p thumbnails
    touch thumbnails/${wsi.replace('.tif', '.jpg').replace('.svs', '.jpg')}
    mkdir -p contours
    touch contours/${wsi.replace('.tif', '.jpg').replace('.svs', '.jpg')}
    mkdir -p contours_geojson
    touch contours_geojson/${wsi.replace('.tif', '.geojson').replace('.svs', '.geojson')}
    """
}

process extract_coordinates {
    publishDir "${params.outdir}", mode: "copy", pattern: "${mag}x_${patch_size}px_${overlap}px_overlap/patches/*.h5"
    publishDir "${params.outdir}", mode: "copy", pattern: "${mag}x_${patch_size}px_${overlap}px_overlap/visualization/*.jpg"
    input:
    tuple val(wsi), path(dataset), path(thumbnails, stageAs: 'thumbnails/*'), path(contours, stageAs: 'contours/*'), path(contours_geojson, stageAs: 'contours_geojson/*'), val(patch_size), val(mag), val(batch_size), val(overlap)
    path(wsi_dir)
    path(trident_dir)
    output:
    tuple val(wsi), path(dataset), val(patch_size), val(mag), val(batch_size), val(overlap), path("${mag}x_${patch_size}px_${overlap}px_overlap/patches/*.h5"), path("${mag}x_${patch_size}px_${overlap}px_overlap/visualization/*.jpg"), emit: coords
    script:
    """
    python ${trident_dir}/run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir . --patch_size ${patch_size} --mag ${mag} \\
        --task coords --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p ${mag}x_${patch_size}px_${overlap}px_overlap/patches/
    touch ${mag}x_${patch_size}px_${overlap}px_overlap/patches/${wsi.replace('.tif', '.h5').replace('.svs', '.h5')}
    mkdir -p ${mag}x_${patch_size}px_${overlap}px_overlap/visualization/
    touch ${mag}x_${patch_size}px_${overlap}px_overlap/visualization/${wsi.replace('.tif', '.jpg').replace('.svs', '.jpg')}
    """
}

process patch_features {
    publishDir "${params.outdir}", mode: "copy", pattern: "${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/*.h5"
    input:
    tuple val(patch_encoder), val(wsi), path(dataset), val(patch_size), val(mag), val(batch_size), val(overlap), path(patches, stageAs: 'patches/*'), path(visualization, stageAs: 'visualization/*')
    path(wsi_dir)
    path(trident_dir)
    output:
    tuple val(patch_encoder), val(patch_size), val(mag), val(batch_size), val(overlap), path("${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/*.h5"), emit: patch_features
    script:
    """
    mkdir -p ${mag}x_${patch_size}px_${overlap}px_overlap/patches/
    mv patches/*.h5 ${mag}x_${patch_size}px_${overlap}px_overlap/patches/

    mkdir -p ${mag}x_${patch_size}px_${overlap}px_overlap/visualization/
    mv visualization/*.jpg ${mag}x_${patch_size}px_${overlap}px_overlap/visualization/

    python ${trident_dir}/run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir . --patch_size ${patch_size} \\
        --mag ${mag} --task feat --patch_encoder ${patch_encoder} \\
        --batch_size ${batch_size} --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p ${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/
    touch ${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/${wsi.replace('.tif', '.h5').replace('.svs', '.h5')}
    """
}

process slide_features {
    publishDir "${params.outdir}", mode: 'copy'
    input:
    tuple path(dataset), path(job_dir), val(patch_encoder), val(slide_encoder), val(patch_size), val(mag), val(batch_size), val(overlap)
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