docker container run \
  -v $PWD:/doesnotmatter \
  --env "ICA_ACCESS_TOKEN" \
  --rm -it \
  ghcr.io/umccr/dracarys:0.8.0 \
    dracarys.R tidy \
      -i gds://development/test-data/dracarys/umccrise/CUP-Pairs8/multiqc_data \
      -o /doesnotmatter/out \
      -p "dracarys"
