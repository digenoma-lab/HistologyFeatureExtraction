include {
    merge_goals;
    check_done;
    intersect_goals_done;
    parse_patches;
    parse_features;
    parse_slide_features;
    parse_segmentation;
    setup_dataset_batch_features;
    setup_dataset_batch_patches;
    setup_dataset_batch_segmentation
} from '../modules/trident.nf'

def non_empty_files = { ch ->
    ch.filter { file -> file.size() > 0 }
}

def attach_dataset = { csv_ch, dataset_ch, with_encoder=false ->
    csv_ch
        .map { row ->
            with_encoder
                ? tuple(row.wsi, row.mag.toInteger(), row.patch_size.toInteger(), row.overlap.toInteger(), row.encoder)
                : tuple(row.wsi, row.mag.toInteger(), row.patch_size.toInteger(), row.overlap.toInteger())
        }
        .combine(dataset_ch, by: 0)
        .map { parts ->
            with_encoder
                ? tuple(parts[1], parts[2], parts[3], parts[4], parts[5], parts[6])
                : tuple(parts[1], parts[2], parts[3], parts[4], parts[5])
        }
}

def group_pending = { ch, with_encoder=false ->
    ch.groupTuple(by: with_encoder ? [0, 1, 2, 3] : [0, 1, 2])
}

def pending_work = { csv_ch, dataset_ch, with_encoder=false ->
    group_pending(attach_dataset(csv_ch, dataset_ch, with_encoder), with_encoder)
}

def pending_work_segmentation = { csv_ch, dataset_ch ->
    csv_ch
        .map { row -> tuple(row.wsi) }
        .combine(dataset_ch, by: 0)
        .map { wsi, case_id, wsi_file -> tuple(case_id, wsi_file) }
        .collate(params.seg_batch_size)
        .map { rows ->
            tuple(
                rows.collect { it[0] },
                rows.collect { it[1] }
            )
        }
}

workflow intersect {
    take:
    goals
    output_dir
    mode
    dataset_join

    main:
    merge_goals(goals)
    check_done(output_dir)

    if (mode == "patches") {
        intersect_goals_done(merge_goals.out.goals, check_done.out.patches)
        parse_patches(non_empty_files(intersect_goals_done.out.goals_not_done))
        pendant = pending_work(parse_patches.out.splitCsv(header: true), dataset_join)
        setup_dataset_batch_patches(pendant)
        dataset_batch = setup_dataset_batch_patches.out.dataset
    }
    else if (mode == "features") {
        intersect_goals_done(merge_goals.out.goals, check_done.out.features)
        parse_features(non_empty_files(intersect_goals_done.out.goals_not_done))
        pendant = pending_work(parse_features.out.splitCsv(header: true), dataset_join, true)
        setup_dataset_batch_features(pendant)
        dataset_batch = setup_dataset_batch_features.out.dataset
    }
    else if (mode == "slide_features") {
        intersect_goals_done(merge_goals.out.goals, check_done.out.slide_features)
        parse_slide_features(non_empty_files(intersect_goals_done.out.goals_not_done))
        pendant = pending_work(parse_slide_features.out.splitCsv(header: true), dataset_join, true)
        setup_dataset_batch_features(pendant)
        dataset_batch = setup_dataset_batch_features.out.dataset
    }
    else if (mode == "segmentation") {
        intersect_goals_done(merge_goals.out.goals, check_done.out.segmentation)
        parse_segmentation(non_empty_files(intersect_goals_done.out.goals_not_done))
        pendant = pending_work_segmentation(parse_segmentation.out.splitCsv(header: true), dataset_join)
        setup_dataset_batch_segmentation(pendant)
        dataset_batch = setup_dataset_batch_segmentation.out.dataset
    }
    else {
        error "Invalid mode: ${mode}"
    }

    emit:
    done = intersect_goals_done.out.goals_done
    non_done = intersect_goals_done.out.goals_not_done
    pendant = pendant
    dataset_batch = dataset_batch
}
