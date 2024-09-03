LongRead project

The LongRead project is a stand-alone research project. As such its infrastructure setup is not integrated with any other stack / account. It's:
- regarded as isolated
- separately bootstrapped
- separate Terraform stacks (not part / workspace of any other stack)
- not integrated or monitored by any of the existing security setups / patrols
- has minimal cost monitoring
- is mainly using the AWS Singapore region (due to AWS HealthOmics limitations)
