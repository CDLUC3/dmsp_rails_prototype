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


## Development with Docker:

The local Docker development environment uses the `docker-compose.yaml` file along with a `.env` file that contains all of the environment variable config required to run the application.

You will first need to make a copy of the `.env.example` file, `cp .env.example .env`, and then update it for your local system.

Once the `.env` file is in place you can build the docker environment (local dynamodb, mysql and Rails app) by running: `docker-compose up`

This will create a small local network running the 2 databases and the Rails application. It uses the `Dockerfile` which runs the `bin/docker-entrypoint` file to initialize the MySQL and NoSQL databases (if necessary) on startup.

**TODO:** For some reason the Rails app is starting before mysql has had a chance to finish starting up, so you have to manually start the app in the Docker desktop console once mysql is running.

Once the system is up and running, you can interact with it on port 8001. For example: `curl -v http://localhost:8001/tags`

### Other helpful commands for the local Docker development environment

Hop into one of the images in the container: `docker-compose exec mysql bash`

Tail the application logs: `docker-compose exec app tail -f ./log/docker.log`

Purge all records from the local NoSQL database: `docker-compose exec app bin/rails nosql:purge`

## Deploying

The Github repository has a corresponding branch for each of the environments except `docker`. When code is merged into the appropriate branch, an AWS CodePipeline is triggered which will run any tests and then build the Docker image within the AWS environment using the `buildspec.yaml` file.

The new image will then be picked up by AWS Fargate and deployed.

See the [dmp-hub-cfn repository](https://github.com/CDLUC3/dmp-hub-cfn) for the CodePipeline and CodeBuild defnitions
