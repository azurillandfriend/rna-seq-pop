rule DifferentialGeneExpression:
    """
    Perform differential expression analysis at the gene-level with DESeq2
    Produce PCAs, heatmaps, volcano plots
    """
    input:
        metadata=config["metadata"],
        genes2transcripts=config["reference"]["genes2transcripts"],
        counts=expand("results/counts/{sample}", sample=samples),
    output:
        csvs=expand("results/genediff/{comp}.csv", comp=config["contrasts"]),
        xlsx=expand(
            "results/genediff/{dataset}_diffexp.xlsx", dataset=config["dataset"]
        ),
        pca="results/counts/PCA.pdf",
        countStats="results/counts/countStatistics.tsv",
        normCounts="results/counts/normCounts.tsv",
    group:
        "diffexp"
    priority: 20
    conda:
        "../envs/diffexp.yaml"
    log:
        "logs/DifferentialGeneExpression.log",
    params:
        DEcontrasts=config["contrasts"],
    script:
        "../scripts/DeseqGeneDE.R"


rule DifferentialIsoformExpression:
    """
    Perform differential expression analysis at the isoform-level with Sleuth
    Produce volcano plots
    """
    input:
        metadata=config["metadata"],
        genes2transcripts=config["reference"]["genes2transcripts"],
        counts=expand("results/counts/{sample}", sample=samples),
    output:
        csvs=expand("results/isoformdiff/{comp}.csv", comp=config["contrasts"]),
        xlsx=expand(
            "results/isoformdiff/{dataset}_isoformdiffexp.xlsx",
            dataset=config["dataset"],
        ),
    group:
        "diffexp"
    priority: 10
    conda:
        "../envs/sleuth.yaml"
    log:
        "logs/DifferentialIsoformExpression.log",
    params:
        DEcontrasts=config["contrasts"],
    script:
        "../scripts/SleuthIsoformsDE.R"


rule progressiveGenesDE:
    """
    Determine if any genes are up/down regulated in same direction in multiple comparisons
    """
    input:
        expand("results/genediff/{dataset}_diffexp.xlsx", dataset=config["dataset"]),
        expand(
            "results/isoformdiff/{dataset}_isoformdiffexp.xlsx",
            dataset=config["dataset"],
        ),
    output:
        expand(
            "results/genediff/{name}.{direction}.progressive.tsv",
            name=config["DifferentialExpression"]["progressiveGenes"]["groups"],
            direction=["up", "down"],
        ),
        expand(
            "results/isoformdiff/{name}.{direction}.progressive.tsv",
            name=config["DifferentialExpression"]["progressiveGenes"]["groups"],
            direction=["up", "down"],
        ),
    params:
        metadata=config["metadata"],
        comps=config["DifferentialExpression"]["progressiveGenes"]["groups"],
        pval=config["DifferentialExpression"]["progressiveGenes"]["padj_threshold"],
        fc=config["DifferentialExpression"]["progressiveGenes"]["fc_threshold"],
    conda:
        "../envs/sleuth.yaml"
    log:
        "logs/progressiveGenesDE.log",
    script:
        "../scripts/ProgressiveDE.R"


# rule GeneSetEnrichment:
#     """
#     Perform hypergeometric test GO terms from a gaf file 
#     """
#     input:
#         metadata=config["metadata"],
#         gaf=config["DifferentialExpression"]["GSEA"]["gaf"],
#         DEresults=expand("results/genediff/{comp}.csv", comp=config["contrasts"]),
#         Fst="results/variantAnalysis/selection/FstPerGene.tsv" if config["VariantAnalysis"]['selection']["activate"] else [],
#     output:
#         expand(
#             "results/gsea/genediff/{comp}.de.tsv",
#             comp=config["contrasts"],
#         ),
#         expand(
#             "results/gsea/fst/{comp}.fst.tsv",
#             comp=config["contrasts"],
#         ) if config["VariantAnalysis"]['selection']["activate"] else [],
#     params:
#         DEcontrasts=config["contrasts"],
#         selection=config["VariantAnalysis"]['selection']["activate"]
#     conda:
#         "../envs/pythonGenomics.yaml"
#     log:
#         "logs/GeneSetEnrichment.log",
#     script:
#         "../scripts/GeneSetEnrichment.py"


rule GeneSetEnrichment_notebook:
    """
    Perform hypergeometric test GO terms from a gaf file 
    """
    input:
        nb = f"{workflow.basedir}/notebooks/gene-set-enrichment-analysis.ipynb",
        kernel = "results/.kernel.set",
        vcf=expand(
            "results/variantAnalysis/vcfs/{dataset}.{contig}.vcf.gz",
            contig=config["contigs"],
            dataset=config["dataset"],
        ),
        metadata=config["metadata"],
        gaf=config["DifferentialExpression"]["GSEA"]["gaf"],
        DEresults=expand("results/genediff/{comp}.csv", comp=config["contrasts"]),
        Fst="results/variantAnalysis/selection/FstPerGene.tsv" if config["VariantAnalysis"]['selection']["activate"] else [],        
    output:
        nb = "results/notebooks/gene-set-enrichment-analysis.ipynb",
        docs_nb = "docs/rna-seq-pop-results/notebooks/gene-set-enrichment-analysis.ipynb",
        gsea_de = expand(
            "results/gsea/genediff/{comp}.de.tsv",
            comp=config["contrasts"],
        ),
        gsea_fst = expand(
            "results/gsea/fst/{comp}.fst.tsv",
            comp=config["contrasts"],
        ) if config["VariantAnalysis"]['selection']["activate"] else [],
    log:
        "logs/notebooks/gene-set-enrichment-analysis.log",
    conda:
        "../envs/pythonGenomics.yaml"
    params:
        DEcontrasts=config["contrasts"],
        selection=config["VariantAnalysis"]['selection']["activate"]
    shell:
        """
        papermill {input.nb} {output.nb} -k pythonGenomics -p metadata_path {input.metadata}  -p comparisons {params.DEcontrasts} -p selection {params.selection} 2> {log}
        cp {output.nb} {output.docs_nb} 2>> {log}
        """


rule Ag1000gSweepsDE:
    """
    Find differentially expressed genes that also lie underneath selective sweeps in the Ag1000g
    """
    input:
        DEresults=expand("results/genediff/{comp}.csv", comp=config["contrasts"]),
        signals="resources/signals.csv",
    output:
        expand(
            "results/genediff/ag1000gSweeps/{comp}_swept.tsv", comp=config["contrasts"]
        ),
    log:
        "logs/Ag1000gSweepsDE.log",
    conda:
        "../envs/pythonGenomics.yaml"
    params:
        DEcontrasts=config["contrasts"],
        pval=config["miscellaneous"]["sweeps"]["padj_threshold"],
        fc=config["miscellaneous"]["sweeps"]["fc_threshold"],
    script:
        "../scripts/Ag1000gSweepsDE.py"


# rule geneFamilies:
#     input:
#         genediff=expand("results/genediff/{comp}.csv", comp=config["contrasts"]),
#         normcounts="results/counts/normCounts.tsv",
#         eggnog=config["miscellaneous"]["GeneFamiliesHeatmap"]["eggnog"],
#         pfam=config["miscellaneous"]["GeneFamiliesHeatmap"]["pfam"],
#     output:
#         heatmaps="results/genediff/GeneFamiliesHeatmap.pdf",
#     conda:
#         "../envs/pythonGenomics.yaml"
#     log:
#         "logs/geneFamilies.log",
#     params:
#         DEcontrasts=config["contrasts"],
#     script:
#         "../scripts/GeneFamiliesHeatmap.py"


rule geneFamilies_notebook:
    """
    Summarise gene expression for gene families
    """
    input:
        nb = f"{workflow.basedir}/notebooks/gene-families-heatmap.ipynb",
        kernel = "results/.kernel.set",
        genediff=expand("results/genediff/{comp}.csv", comp=config["contrasts"]),
        normcounts="results/counts/normCounts.tsv",
        eggnog=config["miscellaneous"]["GeneFamiliesHeatmap"]["eggnog"],
        pfam=config["miscellaneous"]["GeneFamiliesHeatmap"]["pfam"],
    output:
        nb = "results/notebooks/gene-families-heatmap.ipynb",
        docs_nb = "docs/rna-seq-pop-results/notebooks/gene-families-heatmap.ipynb",
        gsea_de = expand(
            "results/gsea/genediff/{comp}.de.tsv",
            comp=config["contrasts"],
        ),
        gsea_fst = expand(
            "results/gsea/fst/{comp}.fst.tsv",
            comp=config["contrasts"],
        ) if config["VariantAnalysis"]['selection']["activate"] else [],
    log:
        "logs/notebooks/gene-families-heatmap.log",
    conda:
        "../envs/pythonGenomics.yaml"
    params:
        DEcontrasts=config["contrasts"],
    shell:
        """
        papermill {input.nb} {output.nb} -k pythonGenomics -p go_path {input.eggnog} -p normcounts_path {input.normcounts} -p pfam_path {input.pfam} -p metadata_path {input.metadata} -p comparisons {params.DEcontrasts} 2> {log}
        cp {output.nb} {output.docs_nb} 2>> {log}
        """
