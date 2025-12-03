include { segmentation; extract_coordinates; slide_features; patch_features } from '../modules/trident.nf'
workflow trident {
    take:
    feature_extractor
    main:
    segmentation(feature_extractor)
    extract_coordinates(segmentation.out.seg)
    patch_features(extract_coordinates.out.coords)
    slide_features(patch_features.out.patch_features)
    emit:
    seg = segmentation.out.seg
    coords = extract_coordinates.out.coords
    patch_features = patch_features.out.patch_features
    slide_features = slide_features.out.slide_features 
}