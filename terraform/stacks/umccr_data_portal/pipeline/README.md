# Portal Workflow Automation

This substack terraform contains Portal Workflow Automation resources for Automation and Orchestration purpose.

## TL;DR

```
terraform workspace select dev
terraform plan
terraform apply
```

## Concept

At high level, there are logically two type of queues - 
- `main` queue for interfacing with "External" services event
- `point-to-point` communication queue for "Internal" events
- See https://github.com/umccr/data-portal-apis/blob/dev/docs/model/architecture_code_design.pdf


## Code

- The `main.tf` contains tha main queue that subscribe to those "externals" facing events.
- Each terraform file name by their _business boundary aggregate_ e.g. `ica.tf`, `oncoanalyser.tf` contains Portal "internal" event queues.
