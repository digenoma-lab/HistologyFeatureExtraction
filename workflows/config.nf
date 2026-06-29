include {
    merge_goals;
    check_done;
    intersect_goals_done;
    parse_patches;
    parse_features;
    parse_slide_features
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
    }
    else if (mode == "features") {
        intersect_goals_done(merge_goals.out.goals, check_done.out.features)
        parse_features(non_empty_files(intersect_goals_done.out.goals_not_done))
        pendant = pending_work(parse_features.out.splitCsv(header: true), dataset_join, true)
    }
    else if (mode == "slide_features") {
        intersect_goals_done(merge_goals.out.goals, check_done.out.slide_features)
        parse_slide_features(non_empty_files(intersect_goals_done.out.goals_not_done))
        pendant = pending_work(parse_slide_features.out.splitCsv(header: true), dataset_join, true)
    }
    else {
        error "Invalid mode: ${mode}"
    }

    emit:
    done = intersect_goals_done.out.goals_done
    non_done = intersect_goals_done.out.goals_not_done
    pendant = pendant
}
