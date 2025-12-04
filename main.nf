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
    combined_configs = preprocessing.out.coords
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
    feature_extraction(combined_configs, dataset, wsi_dir, trident_dir)
}   