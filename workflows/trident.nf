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
    // patch_features: [patch_encoder, wsi, patch_size, mag, batch_size, overlap, features_path]
    //                      [0]        [1]     [2]      [3]     [4]        [5]        [6]
    // all_encoders: [patch_encoder, slide_encoder, patch_size, mag, batch_size, overlap]
    //                    [7]            [8]           [9]      [10]    [11]       [12]
    combined_configs = patch_features
        .combine(all_encoders)
        .filter { item ->
            def match = item[0] == item[7] &&   // patch_encoder
                        item[2] == item[9] &&   // patch_size
                        item[3] == item[10] &&  // mag
                        item[4] == item[11] &&  // batch_size
                        item[5] == item[12]     // overlap
            match
        }
        .map { item ->
            tuple(
                item[7],   // patch_encoder
                item[8],   // slide_encoder
                item[1],   // wsi
                item[2],   // patch_size
                item[3],   // mag
                item[4],   // batch_size
                item[5],   // overlap
                item[6]    // features_path
            )
        }
    slide_features(combined_configs, wsi_dir, trident_path)
    emit:
    slide_features = slide_features.out.slide_features
}