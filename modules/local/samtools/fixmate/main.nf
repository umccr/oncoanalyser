process SAMTOOLS_FIXMATE {
    tag "${meta.id}"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.22.1--h96c455f_0' :
        'biocontainers/samtools:1.22.1--h96c455f_0' }"

    input:
    tuple val(meta), path(cram), path(crai)
    path genome_fasta
    path genome_fai

    output:
    tuple val(meta), path('*.fixmate.bam'), path('*.fixmate.bam.bai'), emit: bam
    path 'versions.yml'                                              , emit: versions
    path '.command.*'                                                , emit: command_files

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def args3 = task.ext.args3 ?: ''

    """
    samtools sort \\
        ${args} \\
        --reference ${genome_fasta} \\
        --threads ${task.cpus} \\
        -n \\
        -o ${cram.baseName}.qname_sort.bam \\
        ${cram}

    samtools fixmate \\
        ${args2} \\
        --threads ${task.cpus} \\
        ${cram.baseName}.qname_sort.bam \\
        /dev/stdout | \\
        samtools sort \\
            ${args3} \\
            --threads ${task.cpus} \\
            -o ${cram.baseName}.fixmate.bam \\
            /dev/stdin

    samtools index --threads ${task.cpus} ${cram.baseName}.fixmate.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | sed -n '/^samtools/ { s/^.* //p }')
    END_VERSIONS
    """

    stub:
    """
    touch ${cram.baseName}.fixmate.bam ${cram.baseName}.fixmate.bam.bai

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
