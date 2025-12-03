include { segmentation; extract_coordinates; slide_features; patch_features } from '../modules/trident.nf'
workflow trident {
    take:
    feature_extractor
    dataset
    wsi_dir
    trident_path
    main:
    segmentation(feature_extractor, dataset, wsi_dir, trident_path)
    extract_coordinates(segmentation.out.seg, dataset, wsi_dir, trident_path)
    patch_features(extract_coordinates.out.coords, dataset, wsi_dir, trident_path)
    slide_features(patch_features.out.patch_features, dataset, wsi_dir, trident_path)
    emit:
    seg = segmentation.out.seg
    coords = extract_coordinates.out.coords
    patch_features = patch_features.out.patch_features
    slide_features = slide_features.out.slide_features 
}