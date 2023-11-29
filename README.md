# DMSP Prototype application

This is the Rails 7 API application that supports the new DMSP UI.

It comproses the "Fargate" portion of this system diagram
<img src="docs/dmsp_prototype.png?raw=true">

## Installation

- Clone this repository
- Create a `.env` file in the project root with the following content:
```
MYSQL_ROOT_PASSWORD=[my-dba-password]
DATABASE_USERNAME=[rails-app-username]
DATABASE_PASSWORD=[rails-app-password]
```
- Build and run the local MySQL container and Rails app: `docker-compose build`
- Start both containers: `docker-compose up`
- Verify that the system is running and available (in a separate terminal window): `curl -v http://localhost:3001/up`

To run DB migrations or other Rails/Rake scripts, you can run the following to connect to the container (in a separate terminal window): `docker-compose run app bash`

## Deploying

The Github repository has a corresponding branch for each of the environments except `docker`. When code is merged into the appropriate branch, an AWS CodePipeline is triggered which will run any tests and then build the Docker image within the AWS environment using the `buildspec.yaml` file.

The new image will then be picked up by AWS Fargate and deployed.

See the [dmp-hub-cfn repository](https://github.com/CDLUC3/dmp-hub-cfn) for the CodePipeline and CodeBuild defnitions
