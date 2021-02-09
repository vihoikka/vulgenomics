rule trimmomatic:
  input:
    forward = "{sample}_S2_R1_001.fastq.gz",
    reverse = "{sample}_S2_R2_001.fastq.gz"
  output:
    forward_paired = "trimmomatic/{sample}_forward_paired.fq.gz",
    forward_unpaired = "trimmomatic/{sample}_forward_unpaired.fq.gz",
    reverse_paired = "trimmomatic/{sample}_reverse_paired.fq.gz",
    reverse_unpaired = "trimmomatic/{sample}_reverse_unpaired.fq.gz"
  message: "Trimming files {input.forward} and {input.reverse}"
  shell:
    "trimmomatic PE {input.forward} {input.reverse} {output.forward_paired} "
    "{output.forward_unpaired} {output.reverse_paired} {output.reverse_unpaired} "
    "LEADING:3 TRAILING:3 MINLEN:36"

rule bowtieDB:
    input:
        "{sample}.fasta"
    params:
        basename = "bowtieDB/{sample}"
    output:
        output1="bowtieDB/{sample}.1.bt2",
        output2="bowtieDB/{sample}.2.bt2",
        output3="bowtieDB/{sample}.3.bt2",
        output4="bowtieDB/{sample}.4.bt2",
        outputrev1="bowtieDB/{sample}.rev.1.bt2",
        outputrev2="bowtieDB/{sample}.rev.2.bt2"
    message: "Creating bowtie 2 database from {input}"
    shell:
        "bowtie2-build {input} {params.basename}"


rule bowtie2:
    params:
        index = "bowtieDB/{sample}"
    input:
        #genome = "bowtieDB/{sample}",
        F = rules.trimmomatic.output.forward_paired,
        R = rules.trimmomatic.output.reverse_paired,
    output:
        "SAM/{sample}.sam"
    message: "Mapping reads to reference with bowtie2"
    shell:
        "bowtie2 -x {params.index} -1 {input.F}"
        "-2 {input.R} -S {output}"

rule samTobam:
    input:
        rules.bowtie2.output
    output:
        "BAM/{sample}.bam"
    message:
        "Converting SAM to BAM"
    shell:
        "samtools view -S -b {input} > {output}"

rule sortBam:
    input:
        rules.samTobam.output
    output:
        "BAM/{sample}.sorted.bam"
    message:
        "Sorting BAM file"
    shell:
        "samtools sort {input} -o {output}"

rule indexBam:
    input:
        rules.sortBam.output
    output:
        toucher = touch("indexBam{sample}.done"),
        BAM = "BAM/{sample}.sorted.bam.bai"
    message:
        "Indexing BAM file"
    shell:
        "samtools index {input} {output.BAM}"

rule pilon:
    input:
        rules.indexBam.output.toucher,
        genome = "{sample}.fasta",
        bam = rules.sortBam.output
    params:
        basename = "pilon_{sample}/pilon_{sample}" #Need to use this because pilon requires a basename instead of an actual output file
    output:
        "pilon_{sample}/pilon_{sample}.fasta"
    message:
        "Polishing with Pilon"
    threads: 40
    shell:
        "pilon --genome {input.genome} --bam {input.bam} --output {params.basename}"
        " --threads 40 --vcf --changes --tracks --fix all --mindepth 10"

rule buscoAfterPolish:
    input:
        rules.pilon.output
    output:
        "BUSCO_afterPolish_{sample}/logs/busco.log"
        #toucher = touch("busco_{sample}.done"),
    params:
        basename = "BUSCO_afterPolish_{sample}"
    shell:
        "busco --mode genome -i {input} -o {params.basename} -l bacteria_odb10 -f"

rule buscoPrePolish:
    input:
        "{sample}.fasta"
    output:
        "BUSCO_prePolish_{sample}/logs/busco.log"
        #toucher = touch("busco_{sample}.done"),
    params:
        basename = "BUSCO_prePolish_{sample}"
    shell:
        "busco --mode genome -i {input} -o {params.basename} -l bacteria_odb10 -f"

rule dummy:
    input:
        after=rules.buscoAfterPolish.output,
        pre=rules.buscoPrePolish.output
    output:
        "{sample}_polish.txt"
    shell:
        "echo '{input.after} {input.pre}' > {output}"
