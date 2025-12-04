include { preprocessing; feature_extraction } from './workflows/trident.nf'
include { segmentation } from './modules/trident.nf'
workflow {
    wsi_dir = channel.value(file(params.wsi_dir))
    all_encoders = channel
        .fromPath(params.feature_extractors)
        .splitCsv(header: true)
        .map { row -> tuple(
            row.patch_encoder,
            row.slide_encoder,
            row.patch_size.toInteger(),
            row.mag.toInteger(),
            row.batch_size.toInteger(),
            row.overlap.toInteger()) 
        }
    unique_configs = all_encoders
        .map { encoder_tuple -> 
            tuple(encoder_tuple[2], encoder_tuple[3], encoder_tuple[4], encoder_tuple[5]) // (patch_size, mag, batch_size, overlap)
        }
        .unique()
    
    dataset = channel.value(file(params.dataset))
    trident_dir = channel.value(file(params.trident_dir))


    segmentation(dataset, wsi_dir, trident_dir)
    preprocessing(unique_configs, segmentation.out.seg, dataset, wsi_dir, trident_dir)
    feature_extraction(all_encoders, preprocessing.out.coords, dataset, wsi_dir, trident_dir)
}   