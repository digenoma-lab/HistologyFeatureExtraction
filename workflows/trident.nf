include { segmentation; extract_coordinates; slide_features; patch_features } from '../modules/trident.nf'
workflow preprocessing {
    take:
    unique_configs
    dataset
    wsi_dir
    trident_path
    main:
    segmentation(unique_configs, dataset, wsi_dir, trident_path)
    extract_coordinates(segmentation.out.seg, dataset, wsi_dir, trident_path)
    emit:
    coords = extract_coordinates.out.coords
}
workflow feature_extraction { 
    take:
    feature_extractor
    dataset
    wsi_dir
    trident_path
    main:
    patch_features(feature_extractor, dataset, wsi_dir, trident_path)
    slide_features(patch_features.out.patch_features, dataset, wsi_dir, trident_path)
}