include { segmentation; extract_coordinates; slide_features; patch_features } from '../modules/trident.nf'
workflow preprocessing {
    take:
    unique_configs
    seg
    dataset
    wsi_dir
    trident_path
    main:
    unique_configs = seg.combine(unique_configs)
    extract_coordinates(unique_configs, dataset, wsi_dir, trident_path)
    emit:
    coords = extract_coordinates.out.coords
}
workflow patch_feature_extraction { 
    take:
    unique_feature_encoders
    coords
    dataset
    wsi_dir
    trident_path
    main:
    combined_configs = coords
        .combine(unique_feature_encoders)
        .filter { item ->
            def match = item[1] == item[6] &&  // patch_size: coords[1] == encoder[6]
                       item[2] == item[7] &&  // mag: coords[2] == encoder[7]
                       item[3] == item[8] &&  // batch_size: coords[3] == encoder[8]
                       item[4] == item[9]    // overlap: coords[4] == encoder[9]
            match
        }
        .map { item ->
            tuple(
                item[0],   // job_dir
                item[5],  // patch_encoder
                item[6],  // patch_size
                item[7],  // mag
                item[8],  // batch_size
                item[9]  // overlap
            )
        }
    patch_features(combined_configs, dataset, wsi_dir, trident_path)
    emit: 
    patch_features = patch_features.out.patch_features
}

workflow slide_feature_extraction {
    take:
    all_encoders
    patch_features
    dataset
    wsi_dir
    trident_path
    main:

    combined_configs = patch_features
        .combine(all_encoders)
        .filter { item ->
            def match = item[1] == item[6] &&  // job_dir: patch_features[0] == encoder[6]
                        item[2] == item[8] &&  // patch_size: patch_features[2] == encoder[7]
                        item[3] == item[9] &&  // mag: patch_features[3] == encoder[8]
                        item[4] == item[10] &&  // batch_size: patch_features[4] == encoder[9]
                        item[5] == item[11]    // overlap: patch_features[5] == encoder[10]
            match
        }
        .map { item ->
            tuple(
                item[0],  // job_dir
                item[1],  // patch_encoder
                item[7],  // slide_encoder
                item[2],  // patch_size
                item[3],  // mag
                item[4],  // batch_size
                item[5],  // overlap
            )
        }
    slide_features(combined_configs, dataset, wsi_dir, trident_path)
}