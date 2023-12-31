process PAVE_SOMATIC {
    tag "${meta.id}"
    label 'process_medium'

    container 'docker.io/scwatts/pave:1.5--0'

    input:
    tuple val(meta), path(sage_vcf)
    path genome_fasta
    val genome_ver
    path genome_fai
    path sage_pon
    path pon_artefacts
    path segment_mappability
    path driver_gene_panel
    path ensembl_data_resources
    path gnomad_resource

    output:
    tuple val(meta), path("*.vcf.gz")    , emit: vcf
    tuple val(meta), path("*.vcf.gz.tbi"), emit: index
    path 'versions.yml'                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    def pon_artefact_arg = pon_artefacts ? "-pon_artefact_file ${pon_artefacts}" : ''

    def pon_filters
    def gnomad_args
    if (genome_ver == '37') {
        pon_filters = 'HOTSPOT:10:5;PANEL:6:5;UNKNOWN:6:0'
        gnomad_args = "-gnomad_freq_file ${gnomad_resource}"
    } else if (genome_ver == '38') {
        pon_filters = 'HOTSPOT:5:5;PANEL:2:5;UNKNOWN:2:0'
        gnomad_args = "-gnomad_freq_dir ${gnomad_resource} -gnomad_load_chr_on_demand"
    } else {
        log.error "got bad genome version: ${genome_ver}"
        System.exit(1)
    }

    """
    java \\
        -Xmx${Math.round(task.memory.bytes * 0.95)} \\
        -jar ${task.ext.jarPath} \\
            -sample ${meta.sample_id} \\
            -vcf_file ${sage_vcf} \\
            -ref_genome ${genome_fasta} \\
            -ref_genome_version ${genome_ver} \\
            -pon_file ${sage_pon} \\
            -pon_filters "${pon_filters}" \\
            ${pon_artefact_arg} \\
            -driver_gene_panel ${driver_gene_panel} \\
            -mappability_bed ${segment_mappability} \\
            -ensembl_data_dir ${ensembl_data_resources} \\
            ${gnomad_args} \\
            -read_pass_only \\
            -output_dir ./

    # NOTE(SW): hard coded since there is no reliable way to obtain version information.
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pave: 1.5
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.sample_id}.sage.pave_somatic.vcf.gz{,.tbi}
    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
