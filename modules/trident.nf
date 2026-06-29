
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
process setup_dataset_batch_features {
    input:
    tuple val(mag), val(patch_size), val(overlap), val(encoder), val(case_ids), val(wsi_files)
    output:
    tuple val(mag), val(patch_size), val(overlap), val(encoder), val(wsi_files), path('dataset.csv'), emit: dataset
    script:
    """
    python - <<'PY'
    import csv
    case_ids = ${groovy.json.JsonOutput.toJson(case_ids)}
    wsi_files = ${groovy.json.JsonOutput.toJson(wsi_files)}
    with open('dataset.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['case_id', 'wsi'])
        writer.writerows(zip(case_ids, wsi_files))
    PY
    """
    stub:
    """
    echo "case_id,wsi" > dataset.csv
    """
}

process setup_dataset_batch_patches {
    input:
    tuple val(mag), val(patch_size), val(overlap), val(case_ids), val(wsi_files)
    output:
    tuple val(mag), val(patch_size), val(overlap), val(wsi_files), path('dataset.csv'), emit: dataset
    script:
    """
    python - <<'PY'
    import csv
    case_ids = ${groovy.json.JsonOutput.toJson(case_ids)}
    wsi_files = ${groovy.json.JsonOutput.toJson(wsi_files)}
    with open('dataset.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['case_id', 'wsi'])
        writer.writerows(zip(case_ids, wsi_files))
    PY
    """
    stub:
    """
    echo "case_id,wsi" > dataset.csv
    """
}
process setup_dataset_batch_segmentation {
    input:
    tuple val(case_ids), val(wsi_files)
    output:
    tuple val(wsi_files), path('dataset.csv'), emit: dataset
    script:
    """
    python - <<'PY'
    import csv
    case_ids = ${groovy.json.JsonOutput.toJson(case_ids)}
    wsi_files = ${groovy.json.JsonOutput.toJson(wsi_files)}
    with open('dataset.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['case_id', 'wsi'])
        writer.writerows(zip(case_ids, wsi_files))
    PY
    """
    stub:
    """
    echo "case_id,wsi" > dataset.csv
    """
}
process check_done {
    input:
    path(results_dir)
    output:
    tuple path("patches.csv"), path("features.csv"), path("slide_features.csv"), emit: done
    path("patches.csv"), emit: patches
    path("features.csv"), emit: features
    path("slide_features.csv"), emit: slide_features
    path("segmentation.csv"), emit: segmentation
    script:
    """
    find -L ${results_dir} -type f -name "*.h5" ! -path "*/pipeline_info/*" | sort > info.csv
    python - <<'PY'
    import os
    from pathlib import Path

    results = Path("${results_dir}")
    outdir = "${params.outdir}".rstrip("/")
    thumb_dir = results / "thumbnails"
    contour_dir = results / "contours"
    geojson_dir = results / "contours_geojson"
    done = []

    def is_file(path: Path) -> bool:
        try:
            return os.path.isfile(os.path.realpath(path))
        except OSError:
            return False

    if thumb_dir.is_dir():
        for thumb in sorted(thumb_dir.glob("*.jpg")):
            stem = thumb.stem
            contour = contour_dir / f"{stem}.jpg"
            geojson = geojson_dir / f"{stem}.geojson"
            if is_file(thumb) and is_file(contour) and is_file(geojson):
                done.append(f"{outdir}/thumbnails/{stem}.jpg")

    Path("segmentation.csv").write_text("\\n".join(done) + ("\\n" if done else ""))
    PY
    grep "/patches/" info.csv > patches.csv
    grep "/slide_features_" info.csv > slide_features.csv
    grep "/features_" info.csv > features.csv
    """
    stub:
    """
    : > patches.csv
    : > features.csv
    : > slide_features.csv
    : > segmentation.csv
    """
}
process merge_goals {
    input:
    val(goals)
    output:
    path("goals.csv"), emit: goals
    script:
    """
    cat > goals.csv <<'EOF'
${goals.join('\n')}
EOF
    """
    stub:
    """
    touch goals.csv
    """
}
process parse_patches {
    input:
    path(patches, stageAs: 'patches_raw.csv')
    output:
    path("patches.csv"), emit: patches
    script:
    """
    python -c "
    import pandas as pd
    df = pd.read_csv('patches_raw.csv', header=None)
    df['wsi'] = df[0].str.split('/').str[-1].str.split('_patches.h5').str[0]
    df['params'] = df[0].str.split('/').str[1]
    df['mag'], df['patch_size'], df['overlap'] = zip(*df['params'].str.split('x_|px_|px_overlap').str[:3])
    df[['wsi', 'mag', 'patch_size', 'overlap']].to_csv('patches.csv', index=False)
    "
    """
    stub:
    """
    echo "mag,patch_size,overlap,slide_img,h5_path" > patches.csv
    """
}

process parse_features {
    input:
    path(features, stageAs: 'features_raw.csv')
    output:
    path("features.csv"), emit: features
    script:
    """
    python -c "
    import pandas as pd
    df = pd.read_csv('features_raw.csv', header=None)
    df['wsi'] = df[0].str.split('/').str[-1].str.split('.h5').str[0]
    df['encoder'] = df[0].str.split('/').str[-2].str.split('features_').str[1]
    df['params'] = df[0].str.split('/').str[1]
    df['mag'], df['patch_size'], df['overlap'] = zip(*df['params'].str.split('x_|px_|px_overlap').str[:3])
    df[['wsi', 'mag', 'patch_size', 'overlap', 'encoder']].to_csv('features.csv', index=False)
    "
    """
    stub:
    """
    echo "wsi,mag,patch_size,overlap,encoder" > features.csv
    """
}
process check_h5 {
    input:
    path(h5_file)
    output:
    tuple path(h5_file), env("valid"), emit: valid
    script:
    """
    python -c "
    import h5py
    try:
        file = h5py.File('${h5_file}', 'r')
        valid = True
    except Exception as e:
        valid = False
    print(valid)
    " > ${h5_file}.valid
    export valid=\$(cat ${h5_file}.valid)
    """
    stub:
    """
    echo "False" > ${h5_file}.valid
    export valid=False
    """
}
process intersect_goals_done {
    input:
    path(goals)
    path(done)
    output:
    path("goals_done.csv"), emit: goals_done
    path("goals_not_done.csv"), emit: goals_not_done
    script:
    """
    : > goals_done.csv
    : > goals_not_done.csv

    if [ -s "${goals}" ] && [ -s "${done}" ]; then
        grep -F -f "${done}" "${goals}" > goals_done.csv || :
        grep -Fv -f "${done}" "${goals}" > goals_not_done.csv || :
    elif [ -s "${goals}" ]; then
        cat "${goals}" > goals_not_done.csv
    fi
    """
    stub:
    """
    touch goals_done.csv
    touch goals_not_done.csv
    """
}
process parse_segmentation {
    input:
    path(segmentation, stageAs: 'segmentation_raw.csv')
    output:
    path("segmentation.csv"), emit: segmentation
    script:
    """
    python -c "
    import pandas as pd
    df = pd.read_csv('segmentation_raw.csv', header=None)
    df['wsi'] = df[0].str.split('/').str[-1].str.rsplit('.', n=1).str[0]
    df[['wsi']].to_csv('segmentation.csv', index=False)
    "
    """
    stub:
    """
    echo "wsi" > segmentation.csv
    """
}

process parse_slide_features {
    input:
    path(slide_features, stageAs: 'slide_features_raw.csv')
    output:
    path("slide_features.csv"), emit: slide_features
    script:
    """
    python -c "
    import pandas as pd
    df = pd.read_csv('slide_features_raw.csv', header=None)
    df['wsi'] = df[0].str.split('/').str[-1].str.split('.h5').str[0]
    df['encoder'] = df[0].str.split('/').str[-2].str.split('slide_features_').str[1]
    df['params'] = df[0].str.split('/').str[1]
    df['mag'], df['patch_size'], df['overlap'] = zip(*df['params'].str.split('x_|px_|px_overlap').str[:3])
    df[['wsi', 'mag', 'patch_size', 'overlap', 'encoder']].to_csv('slide_features.csv', index=False)
    "
    """
    stub:
    """
    echo "wsi,mag,patch_size,overlap,encoder" > slide_features.csv
    """
}

process segmentation {
    publishDir "${params.outdir}", mode: "copy", pattern: "thumbnails/*.jpg"
    publishDir "${params.outdir}", mode: "copy", pattern: "contours/*.jpg"
    publishDir "${params.outdir}", mode: "copy", pattern: "contours_geojson/*.geojson"
    input:
    tuple val(case_ids), val(wsi_files), path(dataset)
    path(wsi_dir)
    path(trident_dir)
    output:
    tuple val(wsi_files), path(dataset), path("thumbnails/*.jpg"), path("contours/*.jpg"), path("contours_geojson/*.geojson"), emit: seg
    script:
    """
    python ${trident_dir}/run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir . --task seg \\
        --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p thumbnails contours contours_geojson
    """
}

process segmentation_batch {
    publishDir "${params.outdir}", mode: "copy", pattern: "thumbnails/*.jpg"
    publishDir "${params.outdir}", mode: "copy", pattern: "contours/*.jpg"
    publishDir "${params.outdir}", mode: "copy", pattern: "contours_geojson/*.geojson"
    input:
    tuple val(wsi_files), path(dataset)
    path(wsi_dir)
    path(trident_dir)
    output:
    tuple val(wsi_files), path(dataset), path("thumbnails/*.jpg"), path("contours/*.jpg"), path("contours_geojson/*.geojson"), emit: seg
    script:
    """
    python ${trident_dir}/run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir . --task seg \\
        --custom_list_of_wsis ${dataset}
    """
    stub:
    """
    mkdir -p thumbnails contours contours_geojson
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
    tuple val(patch_encoder), val(wsi), val(patch_size), val(mag), val(batch_size), val(overlap), path("${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/*.h5"), emit: patch_features
    script:
    """
    python -c "from huggingface_hub import login; login(token='${params.token}')"
    mkdir -p ${mag}x_${patch_size}px_${overlap}px_overlap/patches/
    mv patches/*.h5 ${mag}x_${patch_size}px_${overlap}px_overlap/patches/

    mkdir -p ${mag}x_${patch_size}px_${overlap}px_overlap/visualization/
    mv visualization/*.jpg ${mag}x_${patch_size}px_${overlap}px_overlap/visualization/

    python ${trident_dir}/run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir . --patch_size ${patch_size} \\
        --mag ${mag} --task feat --patch_encoder ${patch_encoder} \\
        --batch_size ${batch_size} --custom_list_of_wsis ${dataset} --max_workers 10
    """
    stub:
    """
    mkdir -p ${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/
    touch ${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/${wsi.replace('.tif', '.h5').replace('.svs', '.h5')}
    """
}

process slide_features {
    publishDir "${params.outdir}", mode: "copy", pattern: "${mag}x_${patch_size}px_${overlap}px_overlap/slide_features_${slide_encoder}/*.h5"
    input:
    tuple val(patch_encoder), val(slide_encoder), val(wsi), val(patch_size), val(mag), val(batch_size), val(overlap), path(features, stageAs: 'features/*')
    path(wsi_dir)
    path(trident_dir)
    output:
    tuple val(slide_encoder), val(wsi), val(patch_size), val(mag), val(batch_size), val(overlap), path("${mag}x_${patch_size}px_${overlap}px_overlap/slide_features_${slide_encoder}/*.h5"), emit: slide_features
    script:
    """
    python -c "from huggingface_hub import login; login(token='${params.token}')"
    mkdir -p ${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/
    mv features/*.h5 ${mag}x_${patch_size}px_${overlap}px_overlap/features_${patch_encoder}/

    python ${trident_dir}/run_batch_of_slides.py --wsi_dir ${wsi_dir} \\
        --job_dir . --patch_size ${patch_size} \\
        --mag ${mag} --task feat --slide_encoder ${slide_encoder} \\
        --batch_size ${batch_size}
    """
    stub:
    """
    mkdir -p ${mag}x_${patch_size}px_${overlap}px_overlap/slide_features_${slide_encoder}/
    touch ${mag}x_${patch_size}px_${overlap}px_overlap/slide_features_${slide_encoder}/${wsi.replace('.tif', '.h5').replace('.svs', '.h5')}
    """
}