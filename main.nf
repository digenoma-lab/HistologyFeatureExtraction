include { preprocessing; patch_feature_extraction; slide_feature_extraction } from './workflows/trident.nf'
include { intersect as intersect_features;
intersect as intersect_patches;
intersect as intersect_slide_features;
intersect as intersect_segmentation } from './workflows/config.nf'
include { segmentation_batch; extract_coordinates_batch } from './modules/trident.nf'
workflow intersect_all {
    take:
    dataset
    dataset_join
    unique_configs
    unique_feature_encoders
    unique_slide_encoders
    output_dir
    main:
    all_combinations_patches = dataset.combine(unique_configs)
    .map{row -> params.outdir + "/" + row[3] + "x_" + row[4] + "px_" + row[5] + "px_overlap/patches/" + row[0] + "_patches.h5"}
    .collect()
    all_combinations_features = dataset.combine(unique_feature_encoders)
    .map{row -> params.outdir + "/" + row[4] + "x_" + row[5] + "px_" + row[6] + "px_overlap/features_" + row[3] + "/" + row[0] + ".h5"}
    .collect()
    all_combinations_slide_features = dataset.combine(unique_slide_encoders)
    .map{row -> params.outdir + "/" + row[4] + "x_" + row[5] + "px_" + row[6] + "px_overlap/slide_features_" + row[3] + "/" + row[0] + ".h5"}
    .collect()

    all_combinations_segmentation = dataset
        .map { row -> params.outdir.replaceAll(/\/$/, '') + "/contours/" + row[0] + ".jpg" }
        .collect()

    intersect_patches(all_combinations_patches, output_dir, "patches", dataset_join)
    intersect_features(all_combinations_features, output_dir, "features", dataset_join)
    intersect_slide_features(all_combinations_slide_features, output_dir, "slide_features", dataset_join)
    intersect_segmentation(all_combinations_segmentation, output_dir, "segmentation", dataset_join)
    emit:
    dataset_patches = intersect_patches.out.dataset_batch
    dataset_features = intersect_features.out.dataset_batch
    dataset_slide_features = intersect_slide_features.out.dataset_batch
    dataset_segmentation = intersect_segmentation.out.dataset_batch
}

workflow {
    wsi_dir = channel.value(file(params.wsi_dir))
    all_encoders = channel
        .fromPath("${projectDir}/params/feature_extractors.csv")
        .splitCsv(header: true)
        .map { row -> tuple(
            row.patch_encoder,
            row.slide_encoder,
            row.mag.toInteger(),
            row.patch_size.toInteger(),
            row.overlap.toInteger(),
            row.batch_size.toInteger())
        }

    unique_configs = all_encoders
        .map { encoder_tuple -> 
            tuple(encoder_tuple[2], encoder_tuple[3], encoder_tuple[4], encoder_tuple[5]) // (mag, patch_size, overlap, batch_size)
        }
        .unique()

    unique_feature_encoders = all_encoders
        .map { encoder_tuple -> 
            tuple(encoder_tuple[0], encoder_tuple[2], encoder_tuple[3], encoder_tuple[4], encoder_tuple[5]) // (patch_encoder, mag, patch_size, overlap, batch_size)
        }
        .unique()

    unique_slide_encoders = all_encoders
        .map { encoder_tuple -> 
            tuple(encoder_tuple[1], encoder_tuple[2], encoder_tuple[3], encoder_tuple[4], encoder_tuple[5]) // (slide_encoder, mag, patch_size, overlap, batch_size)
        }
        .unique()

    dataset = channel.fromPath(params.dataset)
        .splitCsv(header: true)
        .map { row ->
            def wsi_stem = row.wsi.replaceFirst(/\.[^.]+$/, '')
            tuple(wsi_stem, row.case_id, row.wsi)
        }
        .multiMap { wsi_stem, case_id, wsi ->
            intersect: tuple(wsi_stem, case_id, wsi)
            join: tuple(wsi_stem, case_id, wsi)
        }

    trident_dir = channel.value(file(params.trident_dir))
    output_dir = channel.value(file(params.outdir))

    intersect_all(
        dataset.intersect,
        dataset.join,
        unique_configs,
        unique_feature_encoders,
        unique_slide_encoders,
        output_dir
    )
    intersect_all.out.dataset_segmentation.view()
    segmentation_batch(intersect_all.out.dataset_segmentation, output_dir, wsi_dir, trident_dir)
    //intersect_all.out.dataset_patches.view()
    /*extract_coordinates_batch(segmentation_batch.out.seg,
        intersect_all.out.dataset_patches, wsi_dir, trident_dir)*/
}
