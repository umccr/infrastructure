import aws_cdk as core
import aws_cdk.assertions as assertions

from dracarys_cdk.dracarys_cdk_stack import DracarysCdkStack

# example tests. To run these tests, uncomment this file along with the example
# resource in dracarys_cdk/dracarys_cdk_stack.py
def test_sqs_queue_created():
    app = core.App()
    stack = DracarysCdkStack(app, "dracarys-cdk")
    template = assertions.Template.from_stack(stack)

#     template.has_resource_properties("AWS::SQS::Queue", {
#         "VisibilityTimeout": 300
#     })
