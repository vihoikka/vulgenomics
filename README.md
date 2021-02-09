# vulgenomics
General tools for genome assembly etc.

Refassembly
-----------
A simple snakemake pipeline:
  1. Trim reads (Trimmomatic)
  2. Create Bowtie reference
  3. Map to reference with bowtie2
  4. Sam -> Bam -> Sort Bam -> Index Bam (Samtools)
  5. Polish (Pilon)
  6. Genome metrics for before/after polishing (Busco)
