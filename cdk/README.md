# UMCCR cdk apps

The following `apps` directory contains UMCCR CDK-_rised_ application stacks. General guidelines are:

1. If you have a source app then it is better dev your CDK stack along with that repo. Such as a `deploy` folder underneath of your app repo source root.

2. Otherwise, if you are **deploying only** by pulling some App/Container images then you may create a CDK app underneath here.

3. You should have `cdk` CLI installed in your Node.js global scope (or in your Conda-Node.js global scope). 
 
    Example:
    
    ```commandline
    npm install -g aws-cdk
    ```
    
    Or,
    
    ```commandline
    yarn global add aws-cdk
    ```

4. Go with either TypeScript or Python for your CDK. Naturally, TypeScript fit better with frontend code and, Python suit better for backend.
