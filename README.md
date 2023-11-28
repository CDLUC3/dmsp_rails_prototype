# DMSP Prototype application

This is the Rails 7 API application that supports the new DMSP UI.

## Installation

- Clone this repository
- Create a `.env` file in the project root with the following content:
```
MYSQL_ROOT_PASSWORD=[my-dba-password]
DATABASE_USERNAME=[rails-app-username]
DATABASE_PASSWORD=[rails-app-password]
```
- Build and run the local MySQL container: `docker-compose up mysql --build`
- Build and run the Rails API application (in a separate terminal window) : `docker-compose up app --build`
- Verify that the system is running and available (in a separate terminal window) : `curl -v http://localhost:3001/up`

Once both containers have been built the 1st time, you can simply run `docker-compose up`

## Deploying

The Github repository has a corresponding branch for each of the environments except `docker`. When code is merged into the appropriate branch, an AWS CodePipeline is triggered which will run any tests and then build the Docker image within the AWS environment using the `buildspec.yaml` file.

The new image will then be picked up by AWS Fargate and deployed.

See the [dmp-hub-cfn repository](https://github.com/CDLUC3/dmp-hub-cfn) for the CodePipeline and CodeBuild defnitions
