process CUPPA_VISUALISER {
    tag "${meta.id}"
    label 'process_low'

    container 'docker.io/scwatts/cuppa:1.8--1'

    input:
    tuple val(meta), path(cuppa_csv)

    output:
    tuple val(meta), path('*conclusion.txt')     , emit: conclusion
    tuple val(meta), path('*cup_report.pdf')     , emit: report
    tuple val(meta), path('*report.summary.png') , emit: summary_plot
    tuple val(meta), path('*report.features.png'), emit: feature_plot
    tuple val(meta), path('*chart.png')          , emit: chart_plot
    path 'versions.yml'                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    python ${task.ext.chartScriptPath} \\
        -sample ${meta.id} \\
        -sample_data ${cuppa_csv} \\
        -output_dir ./
    Rscript ${task.ext.reportScriptPath} ${meta.id} ./

    # NOTE(SW): hard coded since there is no reliable way to obtain version information.
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cuppa: 1.8
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.cuppa.conclusion.txt
    touch ${meta.id}_cup_report.pdf
    touch ${meta.id}.cup.report.summary.png
    touch ${meta.id}.cup.report.features.png
    touch ${meta.id}.cuppa.chart.png
    echo -e '${task.process}:\\n  stub: noversions\\n' > versions.yml
    """
}
