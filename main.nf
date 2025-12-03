include { trident } from './workflows/trident.nf'
workflow {
    wsi_dir = Channel.fromPath(params.wsi_dir)
    feature_extractors = Channel.fromPath(params.feature_extractors)
        .splitCsv(header: true, sep: ',')
        .map { row -> tuple(row.patch_encoder, row.slide_encoder, row.patch_size, row.mag, row.batch_size, row.overlap) }
    trident(wsi_dir.combine(feature_extractors))
}   