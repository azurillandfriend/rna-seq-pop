rule CheckInputs:
    """
    Check to see that fastq files exist, and reference files are appropriate
    """
    input:
        ref=config["reference"]["genome"].rstrip(".gz"),
    output:
        touch("results/.input.check"),
    params:
        metadata=config["metadata"],
        contigs=config["contigs"],
        gffpath=config["reference"]["gff"],
        gene_names=config["reference"]["genes2transcripts"],
        contrasts=config["contrasts"],
        fastq=config["fastq"]["auto"],
        sweeps=config["miscellaneous"]["sweeps"]["activate"],
    log:
        "logs/CheckInputs.log",
    conda:
        "../envs/pythonGenomics.yaml"
    priority: 50
    script:
        "../scripts/checkInputs.py"



rule fastp:
    input:
        sample = getFASTQs,
    output:
        trimmed=["resources/reads/trimmed/{sample}_1.fastq.gz", "resources/reads/trimmed/{sample}_2.fastq.gz"] if config['fastq']['paired'] else ["resources/reads/trimmed/{sample}_1.fastq.gz"],
        html="results/qc/{sample}.html",
        json="results/qc/{sample}.json",
        logs="logs/fastp/{sample}.log"
    log:
        "logs/fastp/{sample}.log"
    threads: 4
    wrapper:
        "v2.2.1/bio/fastp"



rule BamStats:
    """
    QC alignment statistics
    """
    input:
        bam="results/alignments/{sample}.bam",
        idx="results/alignments/{sample}.bam.bai",
    output:
        stats="results/qc/alignments/{sample}.flagstat",
    log:
        "logs/BamStats/{sample}.log",
    wrapper:
        "v1.15.0/bio/samtools/flagstat"


rule Coverage:
    """
    Calculate coverage with mosdepth
    """
    input:
        bam="results/alignments/{sample}.bam",
        idx="results/alignments/{sample}.bam.bai",
    output:
        "results/qc/coverage/{sample}.mosdepth.summary.txt",
    log:
        "logs/Coverage/{sample}.log",
    conda:
        "../envs/depth.yaml"
    params:
        prefix=lambda w, output: output[0].split(os.extsep)[0],
    threads: 8
    shell:
        "mosdepth --threads {threads} --fast-mode {params.prefix} {input.bam}"


rule vcfStats:
    """
    QC stats of VCF files
    """
    input:
        vcf=expand(
            "results/variantAnalysis/vcfs/{dataset}.{{contig}}.vcf.gz",
            dataset=config["dataset"],
        ),
    output:
        vcfStats="results/qc/vcfs/{contig}.txt",
    conda:
        "../envs/variants.yaml"
    log:
        "logs/vcfStats/{contig}.log",
    shell:
        """
        bcftools stats {input} > {output} 2> {log}
        """

rule multiQC:
    """
    Integrate QC statistics from other tools into a final .html report
    """
    input:
        expand("results/qc/{sample}.json", sample=samples),
        expand(
            "results/qc/vcfs/{contig}.txt", contig=config["contigs"]
        )
        if config["VariantAnalysis"]["activate"]
        else [],
        expand(
            "results/qc/coverage/{sample}.mosdepth.summary.txt", sample=samples
        ),
        expand("results/qc/alignments/{sample}.flagstat", sample=samples),
        expand("results/counts/{sample}", sample=samples),
    output:
        "results/qc/multiQC.html",
    params:
        "results/ resources/ logs/",  # Optional: extra parameters for multiqc.
    log:
        "logs/multiQC.log",
    wrapper:
        "v2.2.1/bio/multiqc"

