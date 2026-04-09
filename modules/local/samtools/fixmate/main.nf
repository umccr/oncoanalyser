process SAMTOOLS_FIXMATE {
    tag "${meta.id}"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.22.1--h96c455f_0' :
        'biocontainers/samtools:1.22.1--h96c455f_0' }"

    input:
    tuple val(meta), path(bam), path(bai)

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
        --threads ${task.cpus} \\
        -n \\
        -o ${bam.baseName}.qname_sort.bam \\
        ${bam}

    samtools fixmate \\
        ${args2} \\
        --threads ${task.cpus} \\
        ${bam.baseName}.qname_sort.bam \\
        /dev/stdout | \\
        samtools sort \\
            ${args3} \\
            --threads ${task.cpus} \\
            -o ${bam.baseName}.fixmate.bam \\
            /dev/stdin

    samtools index --threads ${task.cpus} ${bam.baseName}.fixmate.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | sed -n '/^samtools/ { s/^.* //p }')
    END_VERSIONS
    """

    stub:
    """
    touch ${bam.baseName}.fixmate.bam ${bam.baseName}.fixmate.bam.bai

    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
