include { segmentation; extract_coordinates; slide_features; patch_features } from '../modules/trident.nf'
workflow preprocessing {
    take:
    unique_configs
    seg
    wsi_dir
    trident_path
    main:
    unique_configs = seg.combine(unique_configs)
    extract_coordinates(unique_configs, wsi_dir, trident_path)
    emit:
    coords = extract_coordinates.out.coords
}
workflow patch_feature_extraction { 
    take:
    unique_feature_encoders
    coords
    wsi_dir
    trident_path
    main:
    // coords: [wsi, dataset, patch_size, mag, batch_size, overlap, patches, visualization]
    //          [0]   [1]        [2]       [3]     [4]        [5]      [6]        [7]
    // encoders: [patch_encoder, patch_size, mag, batch_size, overlap]
    //               [8]           [9]      [10]    [11]       [12]
    combined_configs = coords
        .combine(unique_feature_encoders)
        .filter { item ->
            def match = item[2] == item[9] &&   // patch_size
                       item[3] == item[10] &&   // mag
                       item[4] == item[11] &&   // batch_size
                       item[5] == item[12]      // overlap
            match
        }
        .map { item ->
            tuple(
                item[8],   // patch_encoder
                item[0],   // wsi
                item[1],   // dataset
                item[2],   // patch_size
                item[3],   // mag
                item[4],   // batch_size
                item[5],   // overlap
                item[6],   // patches
                item[7]    // visualization
            )
        }
    patch_features(combined_configs, wsi_dir, trident_path)
    emit: 
    patch_features = patch_features.out.patch_features
}

workflow slide_feature_extraction {
    take:
    all_encoders
    patch_features
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
    slide_features(combined_configs, wsi_dir, trident_path)
}