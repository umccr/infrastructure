import re
from enum import Enum

# TODO: fix module load issues and redirect dynamodb methods back here

AGHA_ID_PATTERN = re.compile("A\d{7,8}(?:_mat|_pat|_R1|_R2|_R3)?|unknown")
MD5_PATTERN = re.compile("[0-9a-f]{32}")

FLAGSHIPS = ["ACG", "BM", "CARDIAC", "CHW", "EE", "GI", "HIDDEN", "ICCON", "ID", "KidGen", "LD", "MCD", "MITO", "NMD"]
STAGING_BUCKET = 'agha-gdr-staging'
STORE_BUCKET = 'agha-gdr-store'


class FileType(Enum):
    BAM = "BAM"
    BAM_INDEX = "BAM_INDEX"
    CRAM = "CRAM"
    CRAM_INDEX = "CRAM_INDEX"
    FASTQ = "FASTQ"
    VCF = "VCF"
    VCF_INDEX = "VCF_INDEX"
    MD5 = "MD5"
    MANIFEST = "MANIFEST"
    OTHER = "OTHER"

    def __str__(self):
        return self.value


def get_file_type(file: str) -> FileType:
    if file.lower().endswith(".bam"):
        return FileType.BAM
    elif file.lower().endswith(".bai"):
        return FileType.BAM_INDEX
    elif file.lower().endswith(".cram"):
        return FileType.CRAM
    elif file.lower().endswith(".crai"):
        return FileType.CRAM_INDEX
    elif file.lower().endswith(".fastq"):
        return FileType.FASTQ
    elif file.lower().endswith(".fastq.gz"):
        return FileType.FASTQ
    elif file.lower().endswith(".fq"):
        return FileType.FASTQ
    elif file.lower().endswith(".fq.gz"):
        return FileType.FASTQ
    elif file.lower().endswith(".vcf"):
        return FileType.VCF
    elif file.lower().endswith("vcf.gz"):
        return FileType.VCF
    elif file.lower().endswith(".gvcf"):
        return FileType.VCF
    elif file.lower().endswith("gvcf.gz"):
        return FileType.VCF
    elif file.lower().endswith(".tbi"):
        return FileType.VCF_INDEX
    elif file.lower().endswith(".md5"):
        return FileType.MD5
    elif file.lower().endswith("md5.txt"):
        return FileType.MD5
    elif file.lower().endswith("manifest.txt"):
        return FileType.MANIFEST
    else:
        return FileType.OTHER


def get_flagship_from_key(s3key: str) -> str:
    # the S3 key has to start with the flagship abbreviation
    fs = s3key.split("/")[0]
    if fs not in FLAGSHIPS:
        raise ValueError(f"Unsupported flagship {fs} in S3 key {s3key}!")

    return fs




