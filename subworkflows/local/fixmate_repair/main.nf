//
// Fix mate information
//

import Constants
import Utils

import java.nio.channels.Channel

include { SAMTOOLS_FIXMATE } from '../../../modules/local/samtools/fixmate/main'

workflow FIXMATE_REPAIR {
    take:
    // Sample data
    ch_inputs // channel: [mandatory] [ meta ]

    main:
    // Channel for version.yml files
    // channel: [ versions.yml ]
    ch_versions = Channel.empty()

    // Sort inputs, separate by tumor and normal
    // channel: [ meta ]
    ch_inputs_tumor_sorted = ch_inputs
        .branch { meta ->
            def has_existing = Utils.hasExistingInput(meta, Constants.INPUT.BAM_REDUX_DNA_TUMOR)
            runnable: Utils.hasTumorDnaBam(meta) && !has_existing
            skip: true
        }

    ch_inputs_normal_sorted = ch_inputs
        .branch { meta ->
            def has_existing = Utils.hasExistingInput(meta, Constants.INPUT.BAM_REDUX_DNA_NORMAL)
            runnable: Utils.hasNormalDnaBam(meta) && !has_existing
            skip: true
        }

    ch_inputs_donor_sorted = ch_inputs
        .branch { meta ->
            def has_existing = Utils.hasExistingInput(meta, Constants.INPUT.BAM_REDUX_DNA_DONOR)
            runnable: Utils.hasDonorDnaBam(meta) && !has_existing
            skip: true
        }

    //
    // MODULE: SAMtools fixmate
    //
    // Create process input channel
    // channel: [ meta_samtools, bam, bai ]
    ch_fixmate_inputs = Channel.empty()
        .mix(
            ch_inputs_tumor_sorted.runnable.map { meta -> [meta, Utils.getTumorDnaSample(meta), 'tumor'] },
            ch_inputs_normal_sorted.runnable.map { meta -> [meta, Utils.getNormalDnaSample(meta), 'normal'] },
            ch_inputs_donor_sorted.runnable.map { meta -> [meta, Utils.getDonorDnaSample(meta), 'donor'] },
        )
        .map { meta, meta_sample, sample_type ->
              def meta_samtools = [
                  key: meta.group_id,
                  id: "${meta.group_id}_${meta_sample['sample_id']}",
                  sample_type: sample_type,
              ]

              return [meta_samtools, meta_sample.getOrDefault(Constants.FileType.BAM, null), meta_sample.getOrDefault(Constants.FileType.BAI, null)]
        }

    // Run process
    SAMTOOLS_FIXMATE(
        ch_fixmate_inputs,
    )

    ch_versions = ch_versions.mix(SAMTOOLS_FIXMATE.out.versions)

    // Sort BAMs
    // NOTE(SW): always expect exactly one BAM per sample; nesting within list for downstream compatibility
    // channel: [ meta_samtools, [bam], [bai] ]
    ch_bams_united = SAMTOOLS_FIXMATE.out.bam
        .map { meta_samtools, bam, bai -> return [meta_samtools, [bam], [bai]] }
        .branch { meta_samtools, bam, bai ->
            assert ['tumor', 'normal', 'donor'].contains(meta_samtools.sample_type)
            tumor: meta_samtools.sample_type == 'tumor'
            normal: meta_samtools.sample_type == 'normal'
            donor: meta_samtools.sample_type == 'donor'
            placeholder: true
        }

    // Set outputs, restoring original meta
    // channel: [ meta, [bam], [bai] ]
    ch_bam_tumor_out = Channel.empty()
        .mix(
            WorkflowOncoanalyser.restoreMeta(ch_bams_united.tumor, ch_inputs),
            ch_inputs_tumor_sorted.skip.map { meta -> [meta, [], []] },
        )

    ch_bam_normal_out = Channel.empty()
        .mix(
            WorkflowOncoanalyser.restoreMeta(ch_bams_united.normal, ch_inputs),
            ch_inputs_normal_sorted.skip.map { meta -> [meta, [], []] },
        )

    ch_bam_donor_out = Channel.empty()
        .mix(
            WorkflowOncoanalyser.restoreMeta(ch_bams_united.donor, ch_inputs),
            ch_inputs_donor_sorted.skip.map { meta -> [meta, [], []] },
        )

    emit:
    dna_tumor  = ch_bam_tumor_out  // channel: [ meta, [bam], [bai] ]
    dna_normal = ch_bam_normal_out // channel: [ meta, [bam], [bai] ]
    dna_donor  = ch_bam_donor_out  // channel: [ meta, [bam], [bai] ]

    versions   = ch_versions       // channel: [ versions.yml ]
}
