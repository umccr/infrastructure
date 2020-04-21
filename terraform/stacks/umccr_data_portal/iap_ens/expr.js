// https://iap-docs.readme.io/docs/ens_event-filtering
// https://iap-docs.readme.io/docs/ens_json-expressions

// Write JSON expression and output for ready to use in subscription payload. See subdev.sample.json for example.
// Usage:
// node expr.js

let dev_expr =
    {
        "or": [
            {"equal": [{"path": "$.volumeName"}, "umccr-primary-data-dev"]},
            {"equal": [{"path": "$.volumeName"}, "umccr-run-data-dev"]}
        ]
    };

console.log(JSON.stringify(JSON.stringify(dev_expr)));

let prod_expr =
    {
        "or": [
            {"equal": [{"path": "$.volumeName"}, "umccr-primary-data-prod"]},
            {"equal": [{"path": "$.volumeName"}, "umccr-run-data-prod"]}
        ]
    };

console.log(JSON.stringify(JSON.stringify(prod_expr)));
