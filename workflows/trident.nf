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
workflow feature_extraction { 
    take:
    all_encoders
    coords
    dataset
    wsi_dir
    trident_path
    main:
    combined_configs = coords
        .combine(all_encoders)
        .filter { item ->
            def match = item[1] == item[7] &&  // patch_size: coords[1] == encoder[7]
                       item[2] == item[8] &&  // mag: coords[2] == encoder[8]
                       item[3] == item[9] &&  // batch_size: coords[3] == encoder[9]
                       item[4] == item[10]    // overlap: coords[4] == encoder[10]
            match
        }
        .map { item ->
            tuple(
                item[0],   // job_dir
                item[5],  // patch_encoder
                item[6],  // slide_encoder
                item[7],  // patch_size (usar el del encoder)
                item[8],  // mag (usar el del encoder)
                item[9],  // batch_size (usar el del encoder)
                item[10]  // overlap (usar el del encoder)
            )
        }
    patch_features(combined_configs, dataset, wsi_dir, trident_path)
    slide_features(patch_features.out.patch_features, dataset, wsi_dir, trident_path)
}