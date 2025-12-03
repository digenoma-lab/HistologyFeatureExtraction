include { trident } from './workflows/trident.nf'
workflow {
    wsi_dir = channel.value(file(params.wsi_dir))
    feature_extractors = channel
        .fromPath(params.feature_extractors)
        .splitCsv(header: true)
        .map { row -> tuple(
            row.patch_encoder,
            row.slide_encoder,
            row.patch_size,
            row.mag,
            row.batch_size,
            row.overlap) 
        }
    dataset = channel.value(file(params.dataset))
    trident_dir = channel.value(file(params.trident_dir))
    trident(feature_extractors, dataset, wsi_dir, trident_dir)
    trident.out.slide_features.view()
}   