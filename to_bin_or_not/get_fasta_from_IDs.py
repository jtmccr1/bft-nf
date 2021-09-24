#!/usr/bin/env python 

from Bio import SeqIO
import sys

al = sys.argv[1]
ids = sys.argv[2]

seqs = SeqIO.index(al, "fasta")

with open(ids, "r") as f:
    for line in f:
        l = line.strip()
        seq_rec = seqs[l]
        print(">" + seq_rec.id)
        print(str(seq_rec.seq))
